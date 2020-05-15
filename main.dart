import 'dart:io';
import 'package:path/path.dart' as Path;
// import 'package:args/args.dart';

void main(List<String> args) async {
  exitCode = 0;

  if (args.length == 0) {
    stderr.writeln('error: no path specified');
    exitCode = 1;
    return;
  }

  String path = prepareAsset(args[0]);
  if (path == null) {
    stderr.writeln('error: path not supported');
    exitCode = 2;
    return;
  }

  String ip = await retrieveServerIp();
  if (ip == null) {
    stderr.writeln('error: failed to retrieve ip address');
    exitCode = 3;
    return;
  }

  try {
    await buildHttpServer(path, ip);
  } catch (e) {
    stderr.writeln('failed to share ${args[0]}. error: ${e.toString()}');
    exitCode = 4;
    return;
  }

  stdout.writeln('done!');
}

Future buildHttpServer(String path, String ip) async {
  var urlFileName = Uri.encodeFull(Path.basename(path));

  var server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
  stdout.writeln('http://${ip}:${server.port}/${urlFileName}');
  stdout.writeln('waiting for connection......');

  var connectedCount = 0;

  await for (HttpRequest request in server) {
    if (request.uri.path != '/${urlFileName}') {
      stderr.writeln('warning: url doesn\'t match!');
      continue;
    }

    File file = File(path);

    var response = request.response;
    response.headers.contentType = ContentType.binary;
    response.headers.contentLength = await file.length();

    connectedCount++;
    stdout.writeln('client count: $connectedCount');

    file.openRead().pipe(request.response).then( (v) {
      response.close();

      connectedCount--;
      stdout.writeln('client count: $connectedCount');
    });
    // break;
  }
}

Future<String> retrieveServerIp() async {
  var list = await NetworkInterface.list(type: InternetAddressType.IPv4);
  if (list.length > 0 && list.elementAt(0).addresses.length > 0) {
    return list.elementAt(0).addresses.elementAt(0).address;
  }

  return null;
}

String prepareAsset(String path) {
  var type = FileSystemEntity.typeSync(path);
  switch (type) {
    // case FileSystemEntityType.directory:
    //   Directory tmpPath = Directory('/private/tmp/fileweb/');
    //   if (!tmpPath.existsSync()) {
    //     tmpPath.createSync(recursive: true);
    //   }

    //   // TODO: zip the file into the temp folder
    //   var folderName = Path.basename(path);
    //   print('folder name: $folderName, path: $path');

    //   Process.runSync('zip', arguments);

    //   var zipFilePath = path;

    //   return zipFilePath;
    case FileSystemEntityType.file:
      return path;
    default:
      return null;
  }
}
