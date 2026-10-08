# Model management

> Kontrak aplikasi diperbarui 9 Oktober 2026: khusus prediksi; managed training telah dihapus.
> Status dan langkah kelanjutan agen: [checkpoint](../handoff.md).

Administrators register **inference endpoints** in the Next.js portal or Flutter
client. Raspberry Pi owns the API, access control, storage and prediction queue;
the remote worker interpolates CT frames. Researchers select an available model,
upload their frame archive, preview it and explicitly start prediction.

Administrators can create/edit inference models, configure
write-only worker credentials and TLS verification, toggle availability, check
health, and run an explicit inference test. Editing other fields preserves an
existing worker token when the token field is omitted. There is no model-kind
selector or trainer endpoint registration.

`POST /api/admin/models/sync` imports the catalogue from an explicitly supplied
`base_url` or `AI_MODEL_SERVER_BASE_URL`. There is no hard-coded worker fallback.
Sync updates catalogue metadata without overwriting administrator availability
or existing secrets. Missing catalogue models become offline rather than being
deleted. Researchers see availability through `/api/me/models`, without worker
URLs or credentials.

The queue board `/api/admin/queue` reports live prediction work. Prediction
positions and wait estimates still come from `QueueBoard`; the interpolation
workflow and t=0.5 recursive model contract are unchanged.

Migration `2026_10_09_010000_remove_managed_training` removes legacy training
tables, trainer registry rows, the model `kind` column and training activities.
Inference models and predictions remain. Applied migrations stay as upgrade
history; the October 5 model purge is not replayed. Deployment backs up MySQL,
applies the migration, then runs `php artisan app:cleanup-retired-data` to remove
retired application files. Restoring the retired feature requires the prior
release and database backup; the removal migration has no reverse operation.

A successful API smoke check does not establish scientific acceptance of a
live GPU worker. The acceptance scenarios remain in USER_ACCEPTANCE_TESTING.md.
