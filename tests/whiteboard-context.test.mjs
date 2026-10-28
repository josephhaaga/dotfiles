import assert from "node:assert/strict";
import { test } from "node:test";
import plugin from "../home/dot_config/opencode/local-plugins/whiteboard/index.js";

function fixture() {
  const sessions = new Map();
  const claims = new Map();
  let writes = 0;
  let failPut = false;
  const entries = {
    async list({ sessionID }) { return structuredClone(sessions.get(sessionID) ?? []); },
    async put({ sessionID, key, value }) {
      if (failPut) throw new Error("simulated interrupted put");
      sessions.set(sessionID, [{ key, value: structuredClone(value) }]);
      writes++;
    },
  };
  return {
    sessions, claims, entries,
    get writes() { return writes; },
    failPut(value) { failPut = value; },
    async load(directory = "/fixture/repository") {
      const tools = new Map();
      let before;
      await plugin.setup({
        location: { directory },
        session: { instructions: { entry: entries } },
        storage: { get: async (key) => claims.get(key), set: async (key, value) => { claims.set(key, value); } },
        tool: {
          transform: async (register) => register({ add: (tool) => tools.set(tool.name, tool) }),
          hook: async (name, callback) => { assert.equal(name, "execute.before"); before = callback; },
        },
      });
      const call = async (name, input = {}, sessionID = "ses_alpha", agent = "whiteboard") => {
        const output = await tools.get(name).execute(input, { sessionID, agent });
        return JSON.parse(output.content);
      };
      call.tools = tools;
      call.before = (tool, input = {}, sessionID = "ses_alpha", agent = "whiteboard") => before({ tool, input, sessionID, agent });
      return call;
    },
  };
}

const target = { boardID: "board-alpha", instanceKey: "stable" };

test("setup and read are inert; host supplies session identity", async () => {
  const f = fixture();
  const call = await f.load();
  for (const tool of call.tools.values()) assert.equal(tool.options.codemode, false);
  assert.deepEqual(await call("whiteboard_context"), {
    sessionID: "ses_alpha", repositoryPath: "/fixture/repository", binding: null,
  });
  assert.equal(f.writes, 0);
  assert.equal(f.claims.size, 0);
});

test("identical binding is idempotent and survives plugin/host recreation", async () => {
  const f = fixture();
  const call = await f.load();
  const bound = await call("whiteboard_bind", target);
  await call("whiteboard_bind", target);
  const afterRestart = await f.load();
  assert.deepEqual(await afterRestart("whiteboard_context"), bound);
  assert.equal(f.writes, 1);
});

test("two concurrent sessions retain separate board identities", async () => {
  const f = fixture();
  const call = await f.load();
  const [a, b] = await Promise.all([
    call("whiteboard_bind", target),
    call("whiteboard_bind", { ...target, boardID: "board-beta" }, "ses_beta"),
  ]);
  assert.equal(a.binding.boardID, "board-alpha");
  assert.equal(b.binding.boardID, "board-beta");
  assert.deepEqual(await call("whiteboard_context"), a);
  assert.deepEqual(await call("whiteboard_context", {}, "ses_beta"), b);
});

test("parallel competing binds in one session cannot replace the winner", async () => {
  const call = await fixture().load();
  const result = await Promise.allSettled([
    call("whiteboard_bind", target),
    call("whiteboard_bind", { ...target, boardID: "board-beta" }),
  ]);
  assert.deepEqual(result.map((r) => r.status), ["fulfilled", "rejected"]);
  assert.equal((await call("whiteboard_context")).binding.boardID, "board-alpha");
});

test("another session/location cannot claim an owned board", async () => {
  const f = fixture();
  const a = await f.load();
  const b = await f.load("/fixture/other-repository");
  const results = await Promise.allSettled([
    a("whiteboard_bind", target), b("whiteboard_bind", target, "ses_beta"),
  ]);
  assert.deepEqual(results.map((r) => r.status), ["fulfilled", "rejected"]);
  assert.equal((await b("whiteboard_context", {}, "ses_beta")).binding, null);
});

test("a changed instance or repository fails closed, preserving the saved binding", async () => {
  const f = fixture();
  const call = await f.load();
  await call("whiteboard_bind", target);
  await assert.rejects(call("whiteboard_bind", { ...target, instanceKey: "preview" }), /already bound/);
  const moved = await f.load("/fixture/moved");
  await assert.rejects(moved("whiteboard_context"), /identity/);
  assert.equal(f.writes, 1);
});

test("a forked or corrupt instruction entry cannot select a parent's board", async () => {
  const f = fixture();
  const call = await f.load();
  await call("whiteboard_bind", target);
  f.sessions.set("ses_child", f.sessions.get("ses_alpha"));
  await assert.rejects(call("whiteboard_context", {}, "ses_child"), /identity/);
  f.sessions.set("ses_alpha", [{ key: "dotfiles.whiteboard", value: null }]);
  await assert.rejects(call("whiteboard_context"), /identity/);
});

test("a failed durable write retains the claim and is recoverable only by its owner", async () => {
  const f = fixture();
  const call = await f.load();
  f.failPut(true);
  await assert.rejects(call("whiteboard_bind", target), /interrupted/);
  f.failPut(false);
  const resumed = await f.load();
  await assert.rejects(resumed("whiteboard_bind", target, "ses_beta"), /another task/);
  assert.equal((await resumed("whiteboard_bind", target)).binding.boardID, target.boardID);
});

test("non-Whiteboard agents and blank identifiers cannot mutate bindings", async () => {
  const f = fixture();
  const call = await f.load();
  await assert.rejects(call("whiteboard_bind", target, "ses_alpha", "build"), /Select/);
  for (const input of [{ ...target, boardID: " " }, { ...target, instanceKey: "" }]) {
    await assert.rejects(call("whiteboard_bind", input), /required/);
  }
  assert.equal(f.writes, 0);
});

test("MCP authoring is blocked until binding; another task's board and duplicate creation are refused", async () => {
  const call = await fixture().load();
  await call.before("whiteboard_session_get", { sessionId: target.boardID });
  await assert.rejects(call.before("whiteboard_session_edit", { sessionId: target.boardID }), /Bind/);
  await call("whiteboard_bind", target);
  await call.before("whiteboard_session_edit", { sessionId: target.boardID });
  await assert.rejects(call.before("whiteboard_session_edit", { sessionId: "board-beta" }), /target/);
  await assert.rejects(call.before("whiteboard_review_edit", { reviewId: "board-beta" }), /target/);
  await assert.rejects(call.before("whiteboard_session_get", { sessionId: "board-beta" }), /target/);
  await assert.rejects(call.before("whiteboard_session_create"), /already/);
  // The opt-in mode must not rewrite other agents' tool behavior.
  await call.before("whiteboard_session_edit", { sessionId: "board-beta" }, "ses_alpha", "build");
  await call.before("whiteboard_session_get_instructions");
});
