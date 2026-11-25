// خطوط صفحات مصحف المدينة (مجمع الملك فهد — QCF V1): خط لكل صفحة (٦٠٤ ملف، حوالي ٥٠ ميجا).
// بتتحط جوه التطبيق نفسه (assets/qcf/) عشان المصحف يشتغل من أول فتحة ومن غير نت.
// الملفات مش بتترفع على git — شغّل السكريبت مرة واحدة قبل أول بناء:
//   node tool/fetch_mushaf_fonts.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const BASE = "https://static.qurancdn.com/fonts/quran/hafs/v1/ttf";
const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "assets", "qcf");
fs.mkdirSync(dir, { recursive: true });

let got = 0;
for (let p = 1; p <= 604; p++) {
  const file = path.join(dir, `p${p}.ttf`);
  if (fs.existsSync(file) && fs.statSync(file).size > 1000) continue;
  for (let i = 0; i < 4; i++) {
    try {
      const r = await fetch(`${BASE}/p${p}.ttf`);
      if (!r.ok) throw new Error(String(r.status));
      fs.writeFileSync(file, Buffer.from(await r.arrayBuffer()));
      got++;
      break;
    } catch (e) {
      if (i === 3) throw new Error(`p${p}.ttf: ${e}`);
      await new Promise((res) => setTimeout(res, 1000 * (i + 1)));
    }
  }
  if (p % 50 === 0) console.log(`${p}/604`);
}

const files = fs.readdirSync(dir).filter((f) => f.endsWith(".ttf"));
if (files.length !== 604) throw new Error(`expected 604 fonts, found ${files.length}`);
const size = files.reduce((s, f) => s + fs.statSync(path.join(dir, f)).size, 0);
console.log(`تمام ✅ +${got} ملف — الإجمالي ${(size / 1024 / 1024).toFixed(1)} ميجا في ${dir}`);
