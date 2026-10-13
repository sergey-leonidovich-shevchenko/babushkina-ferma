"use strict";

const $ = (id) => document.getElementById(id);
const labels = {
  procedural: "Векторная форма",
  "shared-image": "Общая картинка",
  "shared-shape": "Повторный силуэт",
  tinted: "Есть окраска",
  "small-silhouette": "Малый силуэт",
};
const providers = {
  alchemy: "Алхимия",
  catalog: "Готовый рисунок",
  furnace: "Материалы горна",
  override: "Выбранная замена",
  research: "Изучение",
  workshop: "Ремёсла",
};
const images = new Map();
const revisions = new WeakMap();
let audit,
  backlog,
  choices = {},
  visible = [],
  page = 0,
  selected;
const PAGE_SIZE = 60;

// Загружает сохранённую текстуру один раз; каталог не содержит ссылок вне снимка ревизии.
function texture(path) {
  if (!/^generated\/sprites\/[0-9a-f]{24}\.png$/.test(path))
    return Promise.reject(new Error("Неверный путь картинки"));
  if (!images.has(path))
    images.set(
      path,
      new Promise((resolve, reject) => {
        const image = new Image();
        image.onload = () => resolve(image);
        image.onerror = reject;
        image.src = "current/" + path.replace(/^generated\//, "");
      }),
    );
  return images.get(path);
}

// Рисует настоящий PNG с игровым цветом, отменяя устаревшую загрузку при быстром выборе.
async function paint(canvas, item, before = false) {
  const revision = (revisions.get(canvas) || 0) + 1;
  revisions.set(canvas, revision);
  const image = await texture(item.icon.image);
  if (revisions.get(canvas) !== revision || !canvas.isConnected) return;
  const context = canvas.getContext("2d");
  context.clearRect(0, 0, canvas.width, canvas.height);
  let source = image;
  if (!before && item.tint !== "ffffff") {
    const colored = document.createElement("canvas");
    colored.width = image.width;
    colored.height = image.height;
    const color = colored.getContext("2d");
    color.drawImage(image, 0, 0);
    color.globalCompositeOperation = "multiply";
    color.fillStyle = "#" + item.tint;
    color.fillRect(0, 0, colored.width, colored.height);
    color.globalCompositeOperation = "destination-in";
    color.drawImage(image, 0, 0);
    source = colored;
  }
  context.imageSmoothingEnabled = true;
  context.drawImage(source, 4, 4, canvas.width - 8, canvas.height - 8);
}

// Обновляет общую карточку фокуса и независимое художественное решение пользователя.
function focus(item) {
  selected = item;
  $("item-name").textContent = item.name;
  $("old-tint").checked = false;
  $("old-tint").disabled = item.tint === "ffffff";
  paint($("item-art"), item).catch(fail);
  $("decision").value = choices[item.id] || "review";
  $("wiki-link").href =
    "http://127.0.0.1:4174/#/items/" + encodeURIComponent(item.id);
  const values = [
    ["ID", item.id],
    ["Группа", providers[item.provider]],
    [
      "Признаки",
      item.flags.map((flag) => labels[flag] || flag).join(" · ") ||
        "Нет автоматических отметок",
    ],
    ["Размер исходника", item.pixels.width + " × " + item.pixels.height],
    ["Источник", item.source.path || item.source.type],
    ["Окраска", "#" + item.tint],
  ];
  $("properties").replaceChildren();
  for (const [key, value] of values) {
    const dt = document.createElement("dt"),
      dd = document.createElement("dd");
    dt.textContent = key;
    dd.textContent = value;
    $("properties").append(dt, dd);
  }
  document
    .querySelectorAll(".item")
    .forEach((button) =>
      button.setAttribute(
        "aria-pressed",
        String(button.dataset.id === item.id),
      ),
    );
}

// Фильтрует весь реестр и сохраняет управляемые страницы без скрытого сокращения каталога.
function render() {
  const query = $("search")
      .value.toLocaleLowerCase("ru")
      .replaceAll("ё", "е")
      .trim(),
    filter = $("filter").value,
    batch = $("family").value;
  visible = audit.entries.filter(
    (item) =>
      (filter === "all" || item.flags.includes(filter)) &&
      (batch === "all" || backlog.itemBatches[item.id] === batch) &&
      (item.name + " " + item.id)
        .toLocaleLowerCase("ru")
        .replaceAll("ё", "е")
        .includes(query),
  );
  page = Math.max(0, Math.min(page, Math.ceil(visible.length / PAGE_SIZE) - 1));
  $("grid").replaceChildren();
  $("results").textContent =
    "Найдено: " +
    visible.length +
    " · решений отмечено: " +
    Object.keys(choices).length;
  const shown = visible.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE);
  for (const item of shown) {
    const button = document.createElement("button");
    button.className = "item";
    button.dataset.id = item.id;
    button.setAttribute("aria-label", item.name);
    button.setAttribute("aria-pressed", String(selected?.id === item.id));
    const canvas = document.createElement("canvas");
    canvas.width = 54;
    canvas.height = 54;
    const name = document.createElement("span");
    name.className = "name";
    name.textContent = item.name;
    const tag = document.createElement("span");
    tag.className = "tag";
    tag.textContent = item.flags.includes("procedural")
      ? "Векторная форма"
      : providers[item.provider];
    button.append(canvas, name, tag);
    button.addEventListener("click", () => focus(item));
    button.addEventListener("focus", () => focus(item));
    $("grid").append(button);
    paint(canvas, item).catch(fail);
  }
  $("page-count").textContent =
    page + 1 + " / " + Math.max(1, Math.ceil(visible.length / PAGE_SIZE));
  $("previous").disabled = page === 0;
  $("next").disabled = (page + 1) * PAGE_SIZE >= visible.length;
  if (
    shown.length &&
    (!selected || !shown.some((item) => item.id === selected.id))
  )
    focus(shown[0]);
  if (!visible.length) {
    selected = undefined;
    $("item-name").textContent = "Ничего не найдено";
    $("properties").replaceChildren();
    revisions.set($("item-art"), (revisions.get($("item-art")) || 0) + 1);
    $("item-art").getContext("2d").clearRect(0, 0, 144, 144);
    $("decision").disabled = true;
    $("old-tint").disabled = true;
    $("wiki-link").removeAttribute("href");
  } else $("decision").disabled = false;
}

// Показывает понятную причину ошибки вместо тихого пустого каталога.
function fail(error) {
  $("results").textContent = "Ошибка загрузки: " + String(error);
  $("results").className = "error";
}

// Инициализирует локальный просмотр и решения ревизии, не обращаясь к состоянию игры.
async function start() {
  const responses = await Promise.all([
    fetch("current/audit.json"),
    fetch("backlog.json"),
  ]);
  if (responses.some((response) => !response.ok))
    throw new Error("Снимок реестра или план отсутствует");
  [audit, backlog] = await Promise.all(
    responses.map((response) => response.json()),
  );
  try {
    choices = JSON.parse(
      localStorage.getItem("moon-art-review-decisions-v1") || "{}",
    );
    if (!choices || Array.isArray(choices) || typeof choices !== "object")
      choices = {};
  } catch {
    choices = {};
  }
  $("stats").textContent =
    audit.stats.items +
    " предметов · " +
    audit.stats.flags.procedural +
    " векторных форм · " +
    audit.stats.flags["shared-image"] +
    " с общей картинкой · " +
    audit.stats.flags.tinted +
    " с окраской";
  $("footer").textContent =
    "Технический снимок игры " +
    audit.version +
    " · новые рисунки ждут выбора · решения ревизии сохраняются только в этом браузере";
  for (const batch of backlog.batches) {
    const option = document.createElement("option");
    option.value = batch.id;
    option.textContent = batch.title + " · " + batch.items.length;
    $("family").append(option);
    const p = document.createElement("p");
    p.textContent =
      batch.title + ": " + batch.items.length + " предметов. " + batch.intent;
    $("batches").append(p);
  }
  $("plan-summary").textContent =
    "Все " +
    audit.stats.items +
    " предметов распределены по " +
    backlog.batches.length +
    " партиям без пропусков и повторов. Дополнительно: 20 базовых ракурсов мебели, 6 районов дорог и адаптация 18 станков.";
  for (const id of ["search", "filter", "family"])
    $(id).addEventListener("input", () => {
      page = 0;
      render();
    });
  $("previous").addEventListener("click", () => {
    page--;
    render();
  });
  $("next").addEventListener("click", () => {
    page++;
    render();
  });
  $("old-tint").addEventListener("change", () => {
    if (selected)
      paint($("item-art"), selected, $("old-tint").checked).catch(fail);
  });
  $("decision").addEventListener("change", () => {
    if (!selected) return;
    if ($("decision").value === "review") delete choices[selected.id];
    else choices[selected.id] = $("decision").value;
    try {
      localStorage.setItem(
        "moon-art-review-decisions-v1",
        JSON.stringify(choices),
      );
    } catch {}
    $("results").textContent =
      "Найдено: " +
      visible.length +
      " · решений отмечено: " +
      Object.keys(choices).length;
  });
  $("export").addEventListener("click", () => {
    const url = URL.createObjectURL(
      new Blob(
        [
          JSON.stringify(
            { schema: 1, sourceVersion: audit.version, decisions: choices },
            null,
            2,
          ),
        ],
        { type: "application/json" },
      ),
    );
    const a = document.createElement("a");
    a.href = url;
    a.download = "moon-valley-art-decisions.json";
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  });
  document.querySelectorAll("[data-page]").forEach((button) =>
    button.addEventListener("click", () => {
      document
        .querySelectorAll("main>section")
        .forEach(
          (section) => (section.hidden = section.id !== button.dataset.page),
        );
      document
        .querySelectorAll("[data-page]")
        .forEach((tab) =>
          tab.setAttribute("aria-pressed", String(tab === button)),
        );
    }),
  );
  render();
}
start().catch(fail);
