<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Model;
use App\Models\ModelUpload;
use App\Services\ModelUploads;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class ModelUploadController extends Controller
{
    public function __construct(private readonly ModelUploads $uploads) {}

    public function index(Request $request)
    {
        $input = $request->validate(['page' => 'sometimes|integer|min:1', 'search' => 'sometimes|nullable|string|max:80']);
        $query = ModelUpload::where('user_id', $request->user()->id);
        if (($input['search'] ?? '') !== '') {
            $term = str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $input['search']);
            $query->where(function ($q) use ($term) {
                $q->whereRaw("JSON_UNQUOTE(JSON_EXTRACT(manifest, '$.model_id')) LIKE ? ESCAPE '!'", ['%'.$term.'%'])
                    ->orWhereRaw("JSON_UNQUOTE(JSON_EXTRACT(manifest, '$.version')) LIKE ? ESCAPE '!'", ['%'.$term.'%']);
            });
        }
        $page = $query->latest('id')->paginate(50);

        return response()->json(['data' => $page->items(), 'pagination' => [
            'current_page' => $page->currentPage(), 'last_page' => $page->lastPage(), 'total' => $page->total(), 'per_page' => 50,
        ]]);
    }

    public function store(Request $request)
    {
        $fields = ['creation_key', 'schema_version', 'model_id', 'version', 'name', 'description', 'framework', 'adapter', 'weight_file', 'sha256', 'size_bytes', 'input'];
        abort_if(array_diff(array_keys($request->all()), $fields), 422, 'Unknown manifest fields.');
        $manifest = $request->validate([
            'creation_key' => 'sometimes|uuid',
            'schema_version' => 'required|integer|in:1', 'model_id' => ['required', 'string', 'max:80', 'regex:/^[a-z0-9]+(?:-[a-z0-9]+)*$/D'],
            'version' => ['required', 'string', 'max:40', 'regex:/^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)$/D'],
            'name' => 'required|string|max:160', 'description' => 'nullable|string|max:4000', 'framework' => 'required|in:tensorflow',
            'adapter' => 'required|in:ginet-tcd-v1', 'weight_file' => 'required|in:model.h5,model.keras',
            'sha256' => ['required', 'regex:/^[0-9a-f]{64}$/D'], 'size_bytes' => 'required|integer|min:1|max:10737418240',
            'input' => 'required|array:width,height,dtype,time_scalar', 'input.width' => 'required|integer|in:1024',
            'input.height' => 'required|integer|in:1024', 'input.dtype' => 'required|in:uint16', 'input.time_scalar' => 'required|numeric|in:0.5',
        ]);
        $key = $manifest['creation_key'] ?? (string) Str::uuid();
        unset($manifest['creation_key']);
        $manifest['description'] ??= '';
        $upload = $this->uploads->creationIntent($request->user(), $key, $manifest);
        $data = $this->uploads->completeCreation($upload);

        return response()->json(['data' => $this->uploads->present($upload, $data)], 201);
    }

    public function show(Request $request, int $id)
    {
        $upload = $this->owned($request, $id);
        $data = $upload->tuf_id
            ? $this->uploads->request('GET', '/management/uploads/'.$upload->tuf_id)
            : $this->uploads->completeCreation($upload);
        $safe = $this->uploads->present($upload, $data);
        if ($data['published'] ?? false) {
            $model = Model::where('managed_model_id', $upload->manifest['model_id'])
                ->where('version', $upload->manifest['version'])->first();
            if (! $model || $model->availability_transition) {
                $this->uploads->synchronize();
            }
        }

        return response()->json(['data' => $safe]);
    }

    public function action(Request $request, int $id, string $action)
    {
        abort_unless(in_array($action, ['renew', 'finalize', 'cancel', 'test', 'publish', 'activate', 'deactivate']), 404);

        return response()->json(['data' => $this->uploads->action($this->owned($request, $id), $action)]);
    }

    public function sync()
    {
        return response()->json(['data' => $this->uploads->synchronize()]);
    }

    private function owned(Request $request, int $id): ModelUpload
    {
        return ModelUpload::where('user_id', $request->user()->id)->findOrFail($id);
    }
}
