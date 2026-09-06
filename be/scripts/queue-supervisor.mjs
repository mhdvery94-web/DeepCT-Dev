#!/usr/bin/env node
/**
 * Keep a queue worker running.
 *
 * `queue:work` is *designed* to exit. Laravel returns 12 when the worker has
 * passed `--memory`, which is a deliberate, graceful recycle: it finishes the
 * job in hand, then quits so something can start it again with a clean heap.
 * On a server that something is supervisor. On this machine there was nothing,
 * so the first heavy job ended the worker for the rest of the day — uploads
 * kept succeeding, jobs kept queueing, and nothing consumed them.
 *
 * That is the single most confusing state this application has, and it had two
 * causes: the worker was never started at all, and once started it retired
 * after a few frames. This fixes the second.
 *
 *   npm run queue
 *
 * Ctrl-C stops it for good rather than triggering a restart — a supervisor you
 * cannot quit is worse than none.
 */

import { spawn } from 'node:child_process';

const PHP_ARGS = [
  '-d', 'memory_limit=1G',
  'artisan', 'queue:work',
  '--tries=1',
  '--timeout=7200',
  // Below the 1G ceiling on purpose: the worker retires itself before PHP
  // kills it, so a heavy job ends in a restart rather than a fatal error that
  // takes the run with it.
  '--memory=768',
];

/**
 * How long to wait before starting again.
 *
 * A recycle is instant and should be; a crash loop is not, and restarting a
 * broken worker forty times a second turns one problem into a log nobody can
 * read. So a clean exit restarts at once, and repeated failures back off.
 */
const QUICK_RESTART_MS = 250;
const BACKOFF_MS = [1000, 2000, 5000, 10000, 30000];

/** Laravel's own code for "I have passed --memory, please restart me". */
const EXIT_MEMORY_LIMIT = 12;

let stopping = false;
let consecutiveFailures = 0;

function stop(signal) {
  stopping = true;
  if (child) child.kill(signal);
}

process.on('SIGINT', () => stop('SIGINT'));
process.on('SIGTERM', () => stop('SIGTERM'));

let child = null;

function start() {
  child = spawn('php', PHP_ARGS, { stdio: 'inherit', shell: false });

  child.on('exit', (code, signal) => {
    child = null;

    if (stopping) {
      process.exit(0);
    }

    if (signal) {
      console.log(`[queue] worker stopped by ${signal}`);
      process.exit(0);
    }

    // 0 and 12 are both the worker deciding its shift is over.
    const planned = code === 0 || code === EXIT_MEMORY_LIMIT;

    if (planned) {
      consecutiveFailures = 0;
      if (code === EXIT_MEMORY_LIMIT) {
        console.log('[queue] worker reached its memory ceiling; restarting');
      }
      setTimeout(start, QUICK_RESTART_MS);
      return;
    }

    const wait = BACKOFF_MS[Math.min(consecutiveFailures, BACKOFF_MS.length - 1)];
    consecutiveFailures++;
    console.error(
      `[queue] worker exited with code ${code}; restarting in ${wait}ms ` +
      `(failure ${consecutiveFailures})`
    );
    setTimeout(start, wait);
  });

  child.on('error', (error) => {
    console.error(`[queue] could not start php: ${error.message}`);
    process.exit(1);
  });
}

console.log('[queue] supervising queue:work — Ctrl-C to stop');
start();
