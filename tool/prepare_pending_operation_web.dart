import 'dart:convert';
import 'dart:io';

/// Run from the project root after pub get. Uses only installed package assets;
/// never downloads code or configures a runtime CDN.
Future<void> main() async {
  final config = File('.dart_tool/package_config.json').absolute;
  final json = jsonDecode(await config.readAsString()) as Map<String, dynamic>;
  final packages = (json['packages'] as List).cast<Map<String, dynamic>>();
  Uri root(String name) {
    final uri = packages.singleWhere((package) => package['name'] == name)['rootUri'] as String;
    return config.uri.resolve(uri.endsWith('/') ? uri : '$uri/');
  }

  final drift = root('drift');
  final sqlite = root('sqlite3');
  final wasm = File.fromUri(drift.resolve('extension/devtools/build/sqlite3.wasm'));
  final hashes = await File.fromUri(
    sqlite.resolve('lib/src/hook/asset_hashes.dart'),
  ).readAsString();
  final expected = RegExp("'sqlite3.wasm': '([a-f0-9]{64})'").firstMatch(hashes)?.group(1);
  if (!await wasm.exists() || expected == null) {
    throw StateError('Installed packages lack a verifiable SQLite WASM asset. No files changed.');
  }
  final hash = await Process.run('shasum', ['-a', '256', wasm.path]);
  if (hash.exitCode != 0 || !(hash.stdout as String).startsWith('$expected ')) {
    throw StateError('SQLite WASM does not match the installed sqlite3 package. No files changed.');
  }

  final generated = File('build/pending_queue_assets/drift_worker.dart.js');
  await generated.parent.create(recursive: true);
  final compiled = await Process.run('dart', [
    'compile',
    'js',
    '--no-source-maps',
    '-O2',
    '--packages=${config.path}',
    File.fromUri(drift.resolve('web/drift_worker.dart')).path,
    '-o',
    generated.path,
  ]);
  stdout.write(compiled.stdout);
  stderr.write(compiled.stderr);
  if (compiled.exitCode != 0) {
    exitCode = compiled.exitCode;
    return;
  }
  await generated.copy('web/drift_worker.dart.js');
  await wasm.copy('web/sqlite3.wasm');
  stdout.writeln('Prepared local Drift worker and SQLite WASM (SHA-256 $expected).');
}
