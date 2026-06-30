import * as Effect from "effect/Effect";
import * as SqlClient from "effect/unstable/sql/SqlClient";

export default Effect.gen(function* () {
  const sql = yield* SqlClient.SqlClient;

  // Sub-agent child threads link back to the thread that spawned them. NULL for
  // normal (top-level) threads. Used to (a) render a child session read-only with
  // a breadcrumb, and (b) exclude child threads from the sidebar/shell list.
  yield* sql`
    ALTER TABLE projection_threads
    ADD COLUMN parent_thread_id TEXT
  `;

  yield* sql`
    CREATE INDEX IF NOT EXISTS idx_projection_threads_parent_thread_id
    ON projection_threads(parent_thread_id)
  `;
});
