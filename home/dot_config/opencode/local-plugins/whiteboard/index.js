// OpenCode V2's Plugin.define is an identity function. The plain Plugin object
// needs no runtime SDK dependency; see docs/whiteboard.md for the API contract.
const bindingKey = "dotfiles.whiteboard";
// Serialize claims across location instances of this module in one host.
let pending = Promise.resolve();

function validateBinding(value, sessionID, repositoryPath) {
  if (value === undefined) return null;
  if (
    value === null || typeof value !== "object" || value.version !== 1 ||
    value.sessionID !== sessionID || value.repositoryPath !== repositoryPath ||
    typeof value.boardID !== "string" || !value.boardID.trim() ||
    typeof value.instanceKey !== "string" || !value.instanceKey.trim()
  ) throw new Error("Whiteboard binding identity is invalid or changed. Ask before rebinding.");
  return value;
}

export default {
  id: "dotfiles.whiteboard",
  async setup(ctx) {
    // Session instructions are the durable source of truth. OpenCode owns their
    // persistence; no session databases, config files, or viewer files are read.
    const entries = ctx.session.instructions.entry;
    const repositoryPath = ctx.location.directory;
    const read = async (sessionID) => {
      const saved = (await entries.list({ sessionID })).find((entry) => entry.key === bindingKey);
      return validateBinding(saved?.value, sessionID, repositoryPath);
    };
    const result = (sessionID, binding) => ({
      content: JSON.stringify({ sessionID, repositoryPath, binding }),
    });

    await ctx.tool.hook("execute.before", async (event) => {
      if (event.agent !== "whiteboard" || !/^whiteboard_(session|review)_/.test(event.tool)) return;
      const saved = await read(event.sessionID);
      if (/_(session|review)_create$/.test(event.tool) && saved) {
        throw new Error("This task already has a Whiteboard. Update its bound board instead of creating another.");
      }
      const input = event.input;
      const boardID = input && typeof input === "object" ? input.sessionId ?? input.reviewId : undefined;
      if (boardID === undefined) return;
      if (saved && saved.boardID !== boardID) throw new Error("MCP target does not match this task's bound Whiteboard.");
      const readOnly = /_(get|history|lens_get|environment)$/.test(event.tool);
      if (!saved && !readOnly) throw new Error("Bind this task's Whiteboard before authoring or opening it.");
    });

    await ctx.tool.transform((editor) => {
      editor.add({
        name: "whiteboard_context",
        description: "Get this invoking OpenCode session's identity and durable Whiteboard binding. Never guesses another session or board.",
        input: { type: "object", properties: {}, additionalProperties: false },
        options: { codemode: false },
        execute: async (_input, context) => result(context.sessionID, await read(context.sessionID)),
      });
      editor.add({
        name: "whiteboard_bind",
        description: "Bind an exact Whiteboard board and instance key to this invoking OpenCode session. Repeating an identical binding is safe; replacing a binding is refused.",
        input: {
          type: "object",
          properties: {
            boardID: { type: "string", minLength: 1 },
            instanceKey: { type: "string", minLength: 1 },
          },
          required: ["boardID", "instanceKey"],
          additionalProperties: false,
        },
        options: { codemode: false },
        execute: async (input, context) => {
          if (context.agent !== "whiteboard") throw new Error("Select the Whiteboard agent before binding.");
          const { boardID, instanceKey } = input;
          if (typeof boardID !== "string" || !boardID.trim() || typeof instanceKey !== "string" || !instanceKey.trim()) {
            throw new Error("An exact board ID and instance key are required.");
          }
          const sessionID = context.sessionID;
          const write = pending.catch(() => {}).then(async () => {
            context.signal?.throwIfAborted();
            const saved = await read(sessionID);
            if (saved && (saved.boardID !== boardID || saved.instanceKey !== instanceKey)) {
              throw new Error("This session is already bound. Resume its saved board or start a new task session.");
            }
            const binding = saved ?? { version: 1, sessionID, repositoryPath, boardID, instanceKey };
            const claimKey = `board/${encodeURIComponent(instanceKey)}/${encodeURIComponent(boardID)}`;
            const owner = await ctx.storage.get(claimKey);
            context.signal?.throwIfAborted();
            if (owner && (owner.sessionID !== sessionID || owner.repositoryPath !== repositoryPath)) {
              throw new Error("This board is claimed by another task session. Resume that session instead.");
            }
            // Claim first: a failed put can be retried by this same session,
            // but another task cannot take a board during crash recovery.
            if (!owner) await ctx.storage.set(claimKey, { sessionID, repositoryPath });
            if (!saved) await entries.put({ sessionID, key: bindingKey, value: binding });
            return result(sessionID, binding);
          });
          pending = write.then(() => {}, () => {});
          return write;
        },
      });
    });
  },
};
