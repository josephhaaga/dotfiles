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
    async load(directory = "/fixture/repository", nativeThreadID) {
      const tools = new Map();
      let before;
      let contextHook;
      const previousThread = process.env.DEV_REVIEW_ASK_THREAD;
      if (nativeThreadID) process.env.DEV_REVIEW_ASK_THREAD = nativeThreadID;
      else delete process.env.DEV_REVIEW_ASK_THREAD;
      try { await plugin.setup({
        location: { directory },
        session: {
          instructions: { entry: entries },
          hook: async (name, callback) => { assert.equal(name, "context"); contextHook = callback; },
        },
        storage: { get: async (key) => claims.get(key), set: async (key, value) => { claims.set(key, value); } },
        tool: {
          transform: async (register) => register({ add: (tool) => tools.set(tool.name, tool) }),
          hook: async (name, callback) => { assert.equal(name, "execute.before"); before = callback; },
        },
      }); } finally {
        if (previousThread === undefined) delete process.env.DEV_REVIEW_ASK_THREAD;
        else process.env.DEV_REVIEW_ASK_THREAD = previousThread;
      }
      const call = async (name, input = {}, sessionID = "ses_alpha", agent = "whiteboard") => {
        const output = await tools.get(name).execute(input, { sessionID, agent });
        return JSON.parse(output.content);
      };
      call.tools = tools;
      call.contextHook = contextHook;
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

test("native ACP Build receives the same board-first policy, without changing ordinary Build", async () => {
  const f = fixture();
  const ordinary = await f.load();
  assert.equal(ordinary.contextHook, undefined);
  const native = await f.load("/fixture/repository", "thread-native");
  const event = { agent: "build", system: [] };
  native.contextHook(event);
  assert.match(event.system[0].text, /# Whiteboard mode/);
  const plan = { agent: "plan", system: [] };
  native.contextHook(plan);
  assert.deepEqual(plan.system, []);
  assert.deepEqual((await native("whiteboard_context")).nativeChat, { threadID: "thread-native" });
  await assert.rejects(native.before("whiteboard_session_create", {}, "ses_native", "build"), /already/);
  await native("whiteboard_bind", target, "ses_native", "build");
  await native.before("whiteboard_session_edit", { sessionId: target.boardID }, "ses_native", "build");
  await assert.rejects(native.before("whiteboard_session_edit", { sessionId: "board-other" }, "ses_native", "build"), /target/);
});

test("native Chat can coauthor a selected terminal board without replacing its task claim", async () => {
  const f = fixture();
  const terminal = await f.load();
  const original = await terminal("whiteboard_bind", target);
  const native = await f.load("/fixture/repository", "thread-native");
  await native("whiteboard_bind", target, "ses_native", "build");
  assert.deepEqual(await terminal("whiteboard_context"), original);
  await assert.rejects(terminal("whiteboard_bind", target, "ses_unrelated"), /another task/);
  const differentThread = await f.load("/fixture/repository", "thread-other");
  await assert.rejects(differentThread("whiteboard_context", {}, "ses_native", "build"), /identity/);
});
