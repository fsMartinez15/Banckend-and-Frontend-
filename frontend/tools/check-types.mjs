import ts from 'typescript';
import { readdir, readFile } from 'node:fs/promises';
let failures = 0;
async function visit(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = `${directory}/${entry.name}`;
    if (entry.isDirectory()) await visit(path);
    else if (path.endsWith('.ts')) {
      const source = ts.createSourceFile(path, await readFile(path, 'utf8'), ts.ScriptTarget.Latest, true);
      function check(node) {
        if (node.kind === ts.SyntaxKind.AnyKeyword) { console.error(`${path}: tipo any no permitido`); failures++; }
        ts.forEachChild(node, check);
      }
      check(source);
    }
  }
}
await visit('src');
if (failures) process.exit(1);
console.log('Código TypeScript sin tipos any explícitos; compilación strict verifica los implícitos.');
