.pragma library

function defaults() {
    return {
        enabled: true,
        position: "bottom",
        iconSize: 48,
        magnification: true,
        magnificationScale: 1.5,
        autoHide: false,
        launchBounce: true,
        showIndicators: true,
        showRecent: true,
        showThumbnails: true,
        previewSize: 160,
        contextPinning: true
    };
}

function desktopId(value) {
    const id = String(value || "").trim();
    return id.endsWith(".desktop") ? id.slice(0, -8) : id;
}

function validDesktopId(value) {
    return typeof value === "string" && value.trim() === value && value.length > 0
            && desktopId(value).length > 0 && value.length <= 512 && !/[\u0000-\u001f/\\]/.test(value);
}

function option(name, value) {
    const standard = defaults();
    if (!Object.prototype.hasOwnProperty.call(standard, name)) return undefined;
    if (typeof standard[name] === "boolean") return typeof value === "boolean" ? value : undefined;
    if (name === "position") return ["bottom", "left", "right"].indexOf(value) >= 0 ? value : undefined;
    if (typeof value !== "number" || !isFinite(value)) return undefined;
    if (name === "previewSize") return Math.round(Math.max(96, Math.min(240, value)));
    if (name === "iconSize") return Math.round(Math.max(32, Math.min(80, value)));
    if (name === "magnificationScale") return Math.max(1, Math.min(2, value));
    return undefined;
}

function decodeConfig(text) {
    try {
        const value = JSON.parse(text);
        if (!value || value.schemaVersion !== 1 || !Array.isArray(value.pinned)
                || value.pinned.length > 128 || !value.options || typeof value.options !== "object"
                || Array.isArray(value.options)) return null;
        const options = defaults();
        for (const name of Object.keys(value.options)) {
            // Legacy manual separators now occupy full icon slots. Discard
            // their old width while preserving all other configuration checks.
            if (name === "separatorSize") {
                if (typeof value.options[name] !== "number" || !isFinite(value.options[name])) return null;
                continue;
            }
            const normalized = option(name, value.options[name]);
            if (normalized === undefined) return null;
            options[name] = normalized;
        }
        const pinned = [];
        const keys = new Set();
        for (const entry of value.pinned) {
            if (!entry || typeof entry !== "object") return null;
            let normalized;
            if (entry.kind === "app" && validDesktopId(entry.desktopId)) {
                normalized = { kind: "app", desktopId: desktopId(entry.desktopId) };
            } else if ((entry.kind === "spacer" || entry.kind === "separator") && typeof entry.id === "string"
                    && /^[A-Za-z0-9_-]{1,80}$/.test(entry.id)) {
                normalized = { kind: "spacer", id: entry.id };
            } else return null;
            const key = pinnedKey(normalized);
            if (keys.has(key)) return null;
            keys.add(key);
            pinned.push(normalized);
        }
        return { schemaVersion: 1, options: options, pinned: pinned };
    } catch (error) {
        return null;
    }
}

function pinnedKey(entry) {
    return entry.kind === "spacer" ? "spacer:" + entry.id : "app:" + desktopId(entry.desktopId);
}

function applicationForWindow(window, applications) {
    // The shell's internal Settings window does not have a desktop file.
    if (window.title === "clavis-control-center") {
        return applications.find(application => application.id === "org.clavis.Settings") || null;
    }
    const identity = desktopId(window.appId);
    if (!identity || identity === "unknown") return null;
    const exact = applications.find(application => desktopId(application.id) === identity);
    if (exact) return exact;
    const byClass = applications.filter(application => String(application.startupClass || "") === window.appId);
    if (byClass.length === 1) return byClass[0];
    // Some XWayland applications differ only in case. Ambiguous names must
    // remain separate instead of being attached to an arbitrary installed app.
    const folded = identity.toLowerCase();
    const fallback = applications.filter(application => desktopId(application.id).toLowerCase() === folded
            || String(application.startupClass || "").toLowerCase() === folded);
    return fallback.length === 1 ? fallback[0] : null;
}

function windowKey(window, application) {
    if (application) return "app:" + desktopId(application.id);
    const identity = String(window.appId || "");
    return identity && identity !== "unknown" ? "window-app:" + identity : "window:" + window.id;
}

function groupWindows(windows, applications, focusOrder) {
    const groups = Object.create(null);
    for (const window of windows) {
        const application = applicationForWindow(window, applications);
        const key = windowKey(window, application);
        if (!groups[key]) groups[key] = { application: application, windows: [] };
        groups[key].windows.push(window);
    }
    for (const key of Object.keys(groups)) {
        groups[key].windows.sort((left, right) => {
            if (!!left.isFocused !== !!right.isFocused) return left.isFocused ? -1 : 1;
            const delta = Number(focusOrder[right.id] || 0) - Number(focusOrder[left.id] || 0);
            return delta || Number(left.id) - Number(right.id);
        });
    }
    return groups;
}

function recentIds(history, applications, excluded, limit) {
    const byId = Object.create(null);
    for (const application of applications) byId[desktopId(application.id)] = application;
    const dates = Object.create(null);
    for (const id of Object.keys(history)) {
        const canonical = desktopId(id);
        const record = history[id];
        if (!byId[canonical] || excluded.has("app:" + canonical) || !record
                || !(Number(record.lastLaunchedAt) > 0)) continue;
        dates[canonical] = Math.max(dates[canonical] || 0, Number(record.lastLaunchedAt));
    }
    return Object.keys(dates).sort((left, right) => dates[right] - dates[left]
            || left.localeCompare(right)).slice(0, limit);
}

function dropPayload(text) {
    try {
        const value = JSON.parse(text);
        if (!value || value.schemaVersion !== 1) return null;
        if (value.kind === "spacer") return { kind: "spacer" };
        return value.kind === "app" && validDesktopId(value.desktopId)
                ? { kind: "app", desktopId: desktopId(value.desktopId) } : null;
    } catch (error) {
        return null;
    }
}

function desktopIdForPath(path, roots) {
    if (typeof path !== "string" || !path.endsWith(".desktop")) return "";
    for (const root of roots) {
        const prefix = root.replace(/\/+$/, "") + "/applications/";
        if (!path.startsWith(prefix)) continue;
        const relative = path.slice(prefix.length);
        if (relative.split("/").some(part => part === ".." || part === "." || !part)) return "";
        const id = desktopId(relative.replace(/\//g, "-"));
        return validDesktopId(id) ? id : "";
    }
    return "";
}

function insertionIndex(value, length) {
    return typeof value === "number" && isFinite(value) && value >= 0
            ? Math.min(length, Math.floor(value)) : length;
}

function movePinned(pinned, key, index) {
    const current = pinned.findIndex(entry => pinnedKey(entry) === key);
    if (current < 0) return null;
    // The UI points at a gap in the current list. Removing an earlier item
    // shifts that gap left; dropping on either side of itself is a no-op.
    const gap = insertionIndex(index, pinned.length);
    const next = pinned.slice();
    const entry = next.splice(current, 1)[0];
    next.splice(gap > current ? gap - 1 : gap, 0, entry);
    return next;
}

function pendingLaunches(pending, groups, now) {
    const result = Object.create(null);
    for (const key of Object.keys(pending)) {
        const launch = pending[key];
        const windows = groups[key] ? groups[key].windows : [];
        if (launch.deadline > now && !windows.some(window => launch.windowIds.indexOf(String(window.id)) < 0))
            result[key] = launch;
    }
    return result;
}

// Preserve delegate identity on window metadata changes and application
// arrivals/removals. This only emits the insert/move/remove operations needed.
function reconcile(model, rows) {
    const wanted = new Set(rows.map(row => row.key));
    for (let index = model.count - 1; index >= 0; index--) {
        if (!wanted.has(model.get(index).key)) model.remove(index);
    }
    for (let index = 0; index < rows.length; index++) {
        const row = rows[index];
        let current = index;
        while (current < model.count && model.get(current).key !== row.key) current++;
        if (current === model.count) model.insert(index, row);
        else {
            if (current !== index) model.move(current, index, 1);
            const previous = model.get(index);
            for (const role of Object.keys(row)) {
                if (previous[role] !== row[role]) model.setProperty(index, role, row[role]);
            }
        }
    }
}
