#!/usr/bin/env node
/**
 * Stop whatever is holding the Octane port, then clear the stale state file.
 *
 * `php artisan octane:stop` cannot do this on Windows: it calls posix_kill(),
 * which does not exist there, so it crashes *before* stopping anything and
 * leaves the old process running. The next `octane:start` then crashes the same
 * way, which is why a restart appears to succeed while changing nothing.
 *
 *   npm run octane:reset && npm run octane
 */

import { execSync } from 'node:child_process';
import { existsSync, rmSync } from 'node:fs';
import { platform } from 'node:process';

const PORT = process.env.OCTANE_PORT ?? '8000';
const STATE_FILE = 'storage/logs/octane-server-state.json';

function pidsOnPort(port) {
  try {
    const cmd =
      platform === 'win32'
        ? `netstat -ano | findstr :${port} | findstr LISTENING`
        : `lsof -ti tcp:${port}`;

    const out = execSync(cmd, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });

    if (platform === 'win32') {
      return [...new Set(
        out.split('\n')
          .map((line) => line.trim().split(/\s+/).pop())
          .filter((pid) => pid && /^\d+$/.test(pid) && pid !== '0'),
      )];
    }

    return out.split('\n').map((s) => s.trim()).filter(Boolean);
  } catch {
    // findstr/lsof exit non-zero when nothing matches.
    return [];
  }
}

const pids = pidsOnPort(PORT);

if (pids.length === 0) {
  console.log(`port ${PORT} is already free`);
} else {
  for (const pid of pids) {
    try {
      execSync(
        platform === 'win32' ? `taskkill /PID ${pid} /F` : `kill -9 ${pid}`,
        { stdio: 'ignore' },
      );
      console.log(`stopped process ${pid} on port ${PORT}`);
    } catch {
      console.warn(`could not stop process ${pid} — stop it manually`);
    }
  }
}

if (existsSync(STATE_FILE)) {
  rmSync(STATE_FILE);
  console.log(`removed ${STATE_FILE}`);
}

console.log('ready — run `npm run octane` (or `npm run serve:all`)');
