// Dibujo de la tecla. Va aparte de plugin.html para poder previsualizarlo.
const KEY_SIZE = 288; // Doble de los 144 px nativos: se ve nítido al reducirse.
const SHORT_NAMES = { xbox_elite: "Elite" };
const ARC_START = Math.PI * 0.75; // Anillo de 270°, abierto por abajo.
const ARC_SWEEP = Math.PI * 1.5;

const GLYPHS = {
  mouse: "M12 3a6 6 0 0 1 6 6v6a6 6 0 0 1-12 0V9a6 6 0 0 1 6-6zM12 7v3.5",
  gamepad: "M7.5 7h9a5 5 0 0 1 4.9 4l.9 4.5a2.7 2.7 0 0 1-4.8 2.2L15 15H9l-2.5 2.7a2.7 2.7 0 0 1-4.8-2.2l.9-4.5A5 5 0 0 1 7.5 7zM7.5 9.5v3M6 11h3M15.5 10.5h.01M17.5 12.5h.01",
  keyboard: "M4.5 6h15A2.5 2.5 0 0 1 22 8.5v7a2.5 2.5 0 0 1-2.5 2.5h-15A2.5 2.5 0 0 1 2 15.5v-7A2.5 2.5 0 0 1 4.5 6zM6 10h.01M10 10h.01M14 10h.01M18 10h.01M8 14h8",
  bolt: "M13.5 2 5 13.5h6L10 22l9-12.5h-6.2z"
};
const DEVICE_GLYPH = { raton: "mouse", dualsense: "gamepad", xbox: "gamepad", xbox_elite: "gamepad", teclado: "keyboard" };

function levelColours(level) {
  if (level == null) return ["#6b6b76", "#6b6b76"];
  if (level >= 30) return ["#2fd9a0", "#7bed8d"];
  if (level >= 15) return ["#ff9d2e", "#ffd25e"];
  return ["#ff4b55", "#ff8a65"];
}

function drawGlyph(ctx, name, cx, cy, size, colour, filled) {
  ctx.save();
  ctx.translate(cx - size / 2, cy - size / 2);
  ctx.scale(size / 24, size / 24);
  ctx.lineCap = ctx.lineJoin = "round";
  ctx.lineWidth = 2;
  ctx.strokeStyle = ctx.fillStyle = colour;
  const path = new Path2D(GLYPHS[name]);
  if (filled) ctx.fill(path); else ctx.stroke(path);
  ctx.restore();
}

function fitFont(ctx, text, weight, size, maxWidth) {
  do {
    ctx.font = `${weight} ${size}px "Segoe UI Variable Display", "Segoe UI", sans-serif`;
    size -= 1;
  } while (ctx.measureText(text).width > maxWidth && size > 10);
}

function renderKey(canvas, key, device) {
  canvas.width = canvas.height = KEY_SIZE;
  const ctx = canvas.getContext("2d");
  ctx.scale(2, 2);
  const level = device ? device.level : null;
  const online = !!(device && device.online);
  const charging = !!(device && device.charging);
  const [from, to] = levelColours(online ? level : null);
  const cx = 72, cy = 70, radius = 57;

  const bg = ctx.createRadialGradient(cx, 48, 8, cx, cy, 112);
  bg.addColorStop(0, "#23232c");
  bg.addColorStop(1, "#0b0b0f");
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, 144, 144);

  ctx.lineCap = "round";
  ctx.lineWidth = 10;
  ctx.strokeStyle = "#2d2d38";
  ctx.beginPath();
  ctx.arc(cx, cy, radius, ARC_START, ARC_START + ARC_SWEEP);
  ctx.stroke();

  if (level != null && level > 0) {
    const end = ARC_START + ARC_SWEEP * Math.min(level, 100) / 100;
    const gradient = ctx.createLinearGradient(cx - radius, cy + radius, cx + radius, cy - radius);
    gradient.addColorStop(0, from);
    gradient.addColorStop(1, to);
    ctx.save();
    if (online) {
      ctx.shadowColor = from;
      ctx.shadowBlur = level < 15 ? 16 : 7;
    }
    ctx.strokeStyle = gradient;
    ctx.beginPath();
    ctx.arc(cx, cy, radius, ARC_START, end);
    ctx.stroke();
    ctx.restore();
  }

  const glyphColour = online ? "#c9c9d4" : "#6b6b76";
  if (charging && online) drawGlyph(ctx, "bolt", cx, 41, 24, "#ffd84a", true);
  else drawGlyph(ctx, DEVICE_GLYPH[key] || "gamepad", cx, 41, 24, glyphColour, false);

  ctx.textAlign = "center";
  ctx.textBaseline = "alphabetic";
  const number = level == null ? "--" : String(level);
  ctx.fillStyle = online ? "#ffffff" : "#85858f";
  fitFont(ctx, number, 700, 46, 70);
  const numberWidth = ctx.measureText(number).width;
  ctx.fillText(number, cx - (level == null ? 0 : 7), 95);
  if (level != null) {
    ctx.fillStyle = online ? "#a8a8b4" : "#6b6b76";
    ctx.font = `600 19px "Segoe UI Variable Display", "Segoe UI", sans-serif`;
    ctx.textAlign = "left";
    ctx.fillText("%", cx - 7 + numberWidth / 2 + 2, 95);
    ctx.textAlign = "center";
  }

  const label = SHORT_NAMES[key] || (device ? device.name : key);
  ctx.fillStyle = online ? "#c9c9d4" : "#6b6b76";
  fitFont(ctx, label, 600, 19, 78);
  ctx.fillText(label, cx, 131);
  return canvas.toDataURL("image/png");
}
