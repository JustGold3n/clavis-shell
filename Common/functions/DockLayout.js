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

// Fan geometry describes the viewport; the native ListView scrolls all files
// through these positions instead of discarding entries after the visible ones.
function folderFan(edge, count, maximumWidth, maximumHeight, labelsLeft, requestedIconSize) {
    const availableWidth = Math.max(0, maximumWidth);
    const availableHeight = Math.max(0, maximumHeight);
    const bottom = edge === "bottom";
    const iconSize = Math.max(64, Math.round(requestedIconSize || 64));
    const step = bottom ? iconSize + 12 : iconSize + 56;
    const baseHeader = iconSize + 52;
    const initialCapacity = Math.max(0, Math.min(10, bottom
        ? Math.floor((availableHeight - baseHeader) / step) : Math.floor((availableWidth - 48) / step)));
    const stackReserve = count > initialCapacity ? 24 : 0;
    const header = baseHeader + stackReserve;
    const capacity = bottom ? Math.max(0, Math.min(10, Math.floor((availableHeight - header) / step)))
                            : initialCapacity;
    const shown = Math.max(0, Math.min(count, capacity));
    const geometry = {
        width: Math.min(availableWidth, bottom ? iconSize + 352 : Math.max(220, shown * step + 48)),
        height: Math.min(availableHeight, bottom ? shown * step + header : iconSize * 2 + 132),
        count: shown, step: step, header: header, stackReserve: stackReserve,
        iconSize: iconSize, iconInset: iconSize / 2 + 44,
        tileWidth: bottom ? Math.max(0, Math.min(iconSize + 276, availableWidth - 76)) : step - 8,
        tileHeight: bottom ? iconSize + 8 : iconSize + 64,
        slots: []
    };
    for (let i = 0; i < shown; ++i)
        geometry.slots.push(folderFanSlot(edge, i, geometry, labelsLeft));
    return geometry;
}

function folderFanSlot(edge, position, geometry, labelsLeft) {
    const fraction = Math.max(0, Math.min(1, position / Math.max(1, geometry.count)));
    const bend = fraction * fraction;
    if (edge === "bottom") {
        const center = labelsLeft ? geometry.width - geometry.iconInset + bend * 28
                                 : geometry.iconInset - bend * 28;
        const iconOffset = geometry.iconSize / 2 + 6;
        const iconCenter = labelsLeft ? geometry.tileWidth - iconOffset : iconOffset;
        return {x: Math.max(0, center - iconCenter), y: geometry.height - geometry.iconSize - 10 - position * geometry.step,
                width: geometry.tileWidth, height: geometry.tileHeight,
                rotation: (labelsLeft ? 10 : -10) * fraction};
    }
    return {x: edge === "left" ? 24 + position * geometry.step
                              : geometry.width - 24 - geometry.tileWidth - position * geometry.step,
            y: 28 + bend * 20, width: geometry.tileWidth, height: geometry.tileHeight,
            rotation: (edge === "left" ? 5 : -5) * fraction};
}
