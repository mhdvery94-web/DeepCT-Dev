<?php

namespace App\Services;

use RuntimeException;

/** Only allowlisted error codes cross the provider boundary. */
class AiProviderException extends RuntimeException {}
