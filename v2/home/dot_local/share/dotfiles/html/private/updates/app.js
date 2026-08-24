const manifest = document.querySelector("#manifest");
const search = document.querySelector("#search");
const filters = document.querySelector("#filters");
const empty = document.querySelector("#empty");
let data = null;
let activeFilter = "all";

function relativeTime(value) {
  const seconds = Math.round((new Date(value).getTime() - Date.now()) / 1000);
  const formatter = new Intl.RelativeTimeFormat(undefined, { numeric: "auto" });
  const ranges = [[60, "second"], [60, "minute"], [24, "hour"], [7, "day"]];
  let amount = seconds;
  for (const [size, unit] of ranges) {
    if (Math.abs(amount) < size) return formatter.format(Math.round(amount), unit);
    amount /= size;
  }
  return formatter.format(Math.round(amount), "week");
}

function text(tag, value, className) {
  const element = document.createElement(tag);
  element.textContent = value;
  if (className) element.className = className;
  return element;
}

function buildNotes(app) {
  if (!app.notes?.length && !app.error) return null;
  const details = document.createElement("details");
  const summary = document.createElement("summary");
  const count = app.updateCount || app.notes?.length || 0;
  summary.textContent = app.error ? "Version check unavailable" : `What changed${count ? ` (${count})` : ""}`;
  details.append(summary);

  if (app.error) {
    details.append(text("p", app.error, "error"));
    return details;
  }

  const list = document.createElement("ul");
  for (const note of app.notes) {
    const item = document.createElement("li");
    const link = document.createElement("a");
    link.href = note.url;
    link.target = "_blank";
    link.rel = "noreferrer";
    link.textContent = note.title || "Release notes";
    item.append(link);
    if (note.body) item.append(text("pre", note.body));
    list.append(item);
  }
  details.append(list);
  return details;
}

function buildCard(app) {
  const article = document.createElement("article");
  article.className = `app status-${app.status}${app.featured ? " featured" : ""}`;

  const heading = document.createElement("div");
  heading.className = "app-heading";
  const title = text("h3", app.name);
  const badge = text("span", app.status === "update" ? "UPDATE" : app.status.toUpperCase(), "badge");
  heading.append(title, badge);

  const versions = document.createElement("div");
  versions.className = "versions";
  const installed = document.createElement("div");
  installed.append(text("span", "PINNED / INSTALLED"), text("strong", app.installed));
  const latest = document.createElement("div");
  latest.append(text("span", "LATEST AVAILABLE"), text("strong", app.latest || "unknown"));
  versions.append(installed, latest);

  const meta = text("p", `${app.manager} / ${app.category}`, "meta");
  article.append(heading, versions, meta);
  const notes = buildNotes(app);
  if (notes) article.append(notes);
  if (app.url) {
    const source = document.createElement("a");
    source.className = "source-link";
    source.href = app.url;
    source.target = "_blank";
    source.rel = "noreferrer";
    source.textContent = "UPSTREAM ↗";
    article.append(source);
  }
  return article;
}

function render() {
  const query = search.value.trim().toLowerCase();
  const visible = data.apps.filter((app) => {
    const filterMatches = activeFilter === "all" || app.status === activeFilter;
    const searchMatches = `${app.name} ${app.category} ${app.manager}`.toLowerCase().includes(query);
    return filterMatches && searchMatches;
  });

  manifest.replaceChildren(...visible.map(buildCard));
  empty.hidden = visible.length !== 0;
}

function load() {
  data = window.__UPDATE_DASHBOARD_DATA__;
  if (!data) throw new Error("Manifest data is unavailable");
  document.querySelector("#update-count").textContent = data.apps.filter((app) => app.status === "update").length;
  document.querySelector("#current-count").textContent = data.apps.filter((app) => app.status === "current").length;
  document.querySelector("#total-count").textContent = data.apps.length;
  document.querySelector("#freshness").textContent = `Checked ${relativeTime(data.generatedAt)}${data.sourceCommit ? ` / source ${data.sourceCommit}` : ""}`;
  render();
}

search.addEventListener("input", render);
filters.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-filter]");
  if (!button) return;
  activeFilter = button.dataset.filter;
  for (const candidate of filters.querySelectorAll("button")) candidate.classList.toggle("active", candidate === button);
  render();
});
function showError(error) {
  manifest.replaceChildren(text("p", error.message, "load-error"));
  document.querySelector("#freshness").textContent = "Manifest unavailable";
}

document.querySelector("#refresh").addEventListener("click", () => location.reload());

try {
  load();
} catch (error) {
  showError(error);
}
