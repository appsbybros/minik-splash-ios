const fs = require("fs");

const parseTsv = (file) => {
  const lines = fs.readFileSync(file, "utf8").trim().split(/\r?\n/);
  const headers = lines.shift().split("\t");
  return lines.map((line) => {
    const values = line.split("\t");
    return Object.fromEntries(headers.map((header, index) => [header, values[index] ?? ""]));
  });
};

const rows = parseTsv("ios/docs/vocabulary-curriculum-audit.tsv");
const hits = [
  "Headphones",
  "Helmet",
  "Compare",
  "Agree",
  "America",
  "United States",
  "Africa",
  "Pixel",
  "Camouflage",
  "Race",
  "Checklist",
  "Library card",
  "Compass rose",
];

for (const hit of hits) {
  const matches = rows.filter((row) => row.english === hit || row.repairedEnglish === hit);
  if (!matches.length) continue;
  console.log(`\n## ${hit}`);
  for (const row of matches) {
    console.log(
      [
        row.sourceArray,
        row.sourceOrdinal,
        row.currentLevel,
        row.proposedBaseLevel,
        row.english,
        row.repairedEnglish,
        row.hebrew,
        row.repairedHebrew,
        row.proposedCategory,
        row.action,
        row.imageMode,
      ].join(" | "),
    );
  }
}
