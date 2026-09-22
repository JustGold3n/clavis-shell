.pragma library

// All windows remain in one row. Scale the gaps too when the row is crowded,
// so no window count or narrow output can force scrolling or negative sizes.
function windowPreviewRow(count, preferredWidth, availableWidth) {
    const available = Math.max(0, availableWidth);
    const margin = Math.min(8, available / 4);
    const inner = available - margin * 2;
    const gap = count > 1 ? Math.min(6, inner / (count * 8)) : 0;
    const cardWidth = count > 0 ? Math.min(Math.max(0, preferredWidth),
                                         (inner - gap * (count - 1)) / count) : 0;
    return { margin: margin, gap: gap, cardWidth: cardWidth,
             width: count > 0 ? margin * 2 + count * cardWidth + (count - 1) * gap : 0 };
}

// Work only in the unscaled coordinate system. Animated icon positions must
// never feed back into magnification, otherwise the dock chases the pointer.
function layout(kinds, preferredSize, available, magnification, sectionSpacing, pointer, sectionBoundary) {
    const gap = 8;
    const padding = 12;
    const count = kinds.length;
    const apps = count;
    const maximum = Math.max(1, Math.min(2, magnification));
    const boundaries = (Array.isArray(sectionBoundary) ? sectionBoundary : [sectionBoundary])
        .filter((v, i, list) => v > 0 && v < count && list.indexOf(v) === i);
    const sectionGap = sectionSpacing + gap;
    const fixed = count * gap + padding * 2 + sectionGap * boundaries.length;
    const reserve = Math.min(apps, 5) * (maximum - 1);
    const size = Math.max(32, Math.min(preferredSize, (available - fixed) / Math.max(1, apps + reserve)));
    const baseLength = fixed + apps * size;
    let baseCursor = padding;
    let cursor = padding;
    let divider = -1;
    const dividers = [];
    const slots = [];
    for (let index = 0; index < count; ++index) {
        if (boundaries.indexOf(index) >= 0) {
            divider = cursor + sectionGap / 2;
            dividers.push(divider);
            baseCursor += sectionGap;
            cursor += sectionGap;
        }
        const baseSpan = size + gap;
        const center = baseCursor + baseSpan / 2;
        const distance = (pointer - center) / (size + gap);
        const scale = !isFinite(pointer) ? 1 : 1 + (maximum - 1) * Math.exp(-distance * distance / 2);
        const span = size * scale + gap;
        slots.push({ center: center, start: cursor, span: span, size: size * scale });
        baseCursor += baseSpan;
        cursor += span;
    }
    return { size: size, baseLength: baseLength, length: cursor + padding, slots: slots, divider: divider, dividers: dividers,
             overflow: baseLength + reserve * size > available };
}

// Keep the automatic group divider out of model indices and persisted pins.
// A provisional drop slot belongs to the pinned group, including new apps.
function sectionBoundary(kinds, pinnedCount, order) {
    let hasPinnedApp = false;
    for (let index = 0; index < kinds.length; ++index) {
        const source = order ? order[index] : index;
        if (source >= pinnedCount)
            return hasPinnedApp ? index : -1;
        if (kinds[index] === "app")
            hasPinnedApp = true;
    }
    return -1;
}

function insertionIndex(slots, position) {
    for (let index = 0; index < slots.length; ++index) {
        if (position < slots[index].start + slots[index].span / 2)
            return index;
    }
    return slots.length;
}

// A drag changes presentation only. Gaps use the persisted list's indices,
// so committing a drop still uses the same insertion contract as DockService.
function previewOrder(kinds, sourceIndex, gapIndex, incomingKind) {
    const order = [];
    const previewKinds = [];
    for (let index = 0; index <= kinds.length; ++index) {
        if (index === gapIndex) {
            order.push(-1);
            previewKinds.push(incomingKind);
        }
        if (index < kinds.length && index !== sourceIndex) {
            order.push(index);
            previewKinds.push(kinds[index]);
        }
    }
    return { order: order, kinds: previewKinds };
}

function removalDistance(edge, x, y, width, height, edgeOffset) {
    if (edge === "left") return x - edgeOffset;
    if (edge === "right") return width - x - edgeOffset;
    return height - y - edgeOffset;
}

// The file area is a separate section even when there are no recent apps.
function sectionBoundaries(kinds, pinnedAppCount, order) {
    const result = [];
    let previous = "";
    let hasApp = false;
    for (let i = 0; i < kinds.length; ++i) {
        const source = order ? order[i] : i;
        const group = ["file", "folder", "trash"].indexOf(kinds[i]) >= 0 ? "files"
            : source < pinnedAppCount ? "pinned" : "running";
        if (i > 0 && group !== previous && (group === "files" || hasApp)) result.push(i);
        previous = group;
        if (kinds[i] === "app") hasApp = true;
    }
    return result;
}

function folderFan(edge, count, maximumWidth, maximumHeight, labelsLeft) {
    const availableWidth = Math.max(0, maximumWidth);
    const availableHeight = Math.max(0, maximumHeight);
    const bottom = edge === "bottom";
    const shown = Math.max(0, Math.min(count, 7, bottom
        ? Math.floor((availableHeight - 62) / 72) : Math.floor((availableWidth - 24) / 112)));
    const width = Math.min(availableWidth, bottom ? 380 : Math.max(220, shown * 112 + 24));
    const height = Math.min(availableHeight, bottom ? shown * 72 + 62 : 190);
    const slots = [];
    for (let i = 0; i < shown; ++i) {
        const bend = Math.pow(i / Math.max(1, shown - 1), 2);
        slots.push(bottom
            ? {x: labelsLeft ? 48 - bend * 38 : 10 + bend * 38, y: height - 64 - i * 72,
               width: Math.max(0, width - 55), height: 64}
            : {x: 12 + (edge === "left" ? i : shown - 1 - i) * 112, y: 6 + bend * 24,
               width: 104, height: 112});
    }
    return {width: width, height: height, count: shown, slots: slots};
}
