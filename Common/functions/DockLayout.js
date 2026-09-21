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
function layout(kinds, preferredSize, available, magnification, separatorSize, pointer, sectionBoundary) {
    const gap = 8;
    const padding = 12;
    const count = kinds.length;
    const apps = kinds.filter(kind => kind !== "separator").length;
    const separators = count - apps;
    const maximum = Math.max(1, Math.min(2, magnification));
    const sectionGap = sectionBoundary > 0 && sectionBoundary < count ? separatorSize + gap : 0;
    const fixed = separators * separatorSize + count * gap + padding * 2 + sectionGap;
    const reserve = Math.min(apps, 5) * (maximum - 1);
    const size = Math.max(32, Math.min(preferredSize, (available - fixed) / Math.max(1, apps + reserve)));
    const baseLength = fixed + apps * size;
    let baseCursor = padding;
    let cursor = padding;
    let divider = -1;
    const slots = [];
    for (let index = 0; index < count; ++index) {
        if (sectionGap && index === sectionBoundary) {
            divider = cursor + sectionGap / 2;
            baseCursor += sectionGap;
            cursor += sectionGap;
        }
        const separator = kinds[index] === "separator";
        const baseSpan = (separator ? separatorSize : size) + gap;
        const center = baseCursor + baseSpan / 2;
        const distance = (pointer - center) / (size + gap);
        const scale = separator || !isFinite(pointer) ? 1 : 1 + (maximum - 1) * Math.exp(-distance * distance / 2);
        const span = (separator ? separatorSize : size * scale) + gap;
        slots.push({ center: center, start: cursor, span: span, size: size * scale });
        baseCursor += baseSpan;
        cursor += span;
    }
    return { size: size, baseLength: baseLength, length: cursor + padding, slots: slots, divider: divider,
             overflow: baseLength + reserve * size > available };
}

// Keep the automatic group divider out of model indices and persisted pins.
// A provisional drop slot belongs to the pinned group, including new apps.
function sectionBoundary(kinds, pinnedCount, order) {
    let hasPinnedApp = false;
    for (let index = 0; index < kinds.length; ++index) {
        const source = order ? order[index] : index;
        if (source >= pinnedCount)
            return hasPinnedApp && kinds[index - 1] !== "separator" ? index : -1;
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
