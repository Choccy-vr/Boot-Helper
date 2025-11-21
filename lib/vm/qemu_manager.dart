import 'dart:io';
import 'dart:convert';
import '../misc/logger.dart';

class QemuManager {
  Process? _currentProcess;

  // Get current OS
  String get currentOS {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  // Get default QEMU executable for current OS
  String get defaultQemuExecutable {
    if (Platform.isWindows) return 'qemu-system-x86_64.exe';
    return 'qemu-system-x86_64';
  }

  // Check if QEMU is installed
  Future<bool> isQemuInstalled() async {
    try {
      ProcessResult result = await Process.run(defaultQemuExecutable, [
        '--version',
      ], runInShell: Platform.isWindows);
      return result.exitCode == 0;
    } catch (e) {
      AppLogger.debug('QEMU not found: $e');
      return false;
    }
  }

  // Get QEMU version if installed
  Future<String?> getQemuVersion() async {
    try {
      ProcessResult result = await Process.run(defaultQemuExecutable, [
        '--version',
      ], runInShell: Platform.isWindows);
      if (result.exitCode == 0) {
        return result.stdout.toString().split('\n').first.trim();
      }
    } catch (e) {
      AppLogger.debug('Could not get QEMU version: $e');
    }
    return null;
  }

  // Run a QEMU command directly
  Future<bool> runCommand(String command) async {
    if (_currentProcess != null) {
      AppLogger.warning('VM already running! PID: ${_currentProcess!.pid}');
      return false;
    }

    try {
      AppLogger.info('Running QEMU command: $command');

      // Parse command into executable and arguments
      List<String> parts = command.split(' ');
      String executable = parts.first;
      List<String> args = parts.sublist(1);

      _currentProcess = await Process.start(
        executable,
        args,
        runInShell: Platform.isWindows,
      );

      // Handle stdout
      _currentProcess!.stdout.transform(utf8.decoder).listen((data) {
        String cleanData = data.trim();
        if (cleanData.isNotEmpty) {
          AppLogger.debug('QEMU: $cleanData');
        }
      });

      // Handle stderr
      _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
        String cleanData = data.trim();
        if (cleanData.isNotEmpty) {
          AppLogger.debug('QEMU: $cleanData');
        }
      });

      // Handle process exit
      _currentProcess!.exitCode.then((exitCode) {
        AppLogger.info('QEMU process exited with code: $exitCode');
        _currentProcess = null;
      });

      // Give QEMU time to start
      await Future.delayed(Duration(milliseconds: 500));

      // Check if process is still running
      try {
        int pid = _currentProcess!.pid;
        AppLogger.info('QEMU started with PID: $pid');
        return true;
      } catch (e) {
        AppLogger.error('QEMU process died immediately: $e');
        _currentProcess = null;
        return false;
      }
    } catch (e) {
      AppLogger.error('Failed to start QEMU: $e');
      _currentProcess = null;
      return false;
    }
  }

  // Start VM from ISO with a command string
  Future<bool> startVMFromISO(String isoPath, String qemuCommand) async {
    if (_currentProcess != null) {
      AppLogger.warning('VM already running! PID: ${_currentProcess!.pid}');
      return false;
    }

    // Check if ISO file exists
    File isoFile = File(isoPath);
    if (!await isoFile.exists()) {
      AppLogger.warning('ISO file not found: $isoPath');
      return false;
    }

    // Replace {iso} placeholder in command with actual ISO path
    String command = qemuCommand.replaceAll('{iso}', isoPath);

    return runCommand(command);
  }

  // Stop the VM
  Future<bool> stopVM() async {
    if (_currentProcess == null) {
      AppLogger.info('No VM is currently running');
      return false;
    }

    try {
      int pid = _currentProcess!.pid;
      AppLogger.info('Stopping QEMU VM (PID: $pid)...');

      // Try to send quit command to QEMU monitor
      try {
        _currentProcess!.stdin.writeln('quit');
        await _currentProcess!.stdin.flush();

        int? exitCode = await _currentProcess!.exitCode.timeout(
          Duration(seconds: 5),
          onTimeout: () => -1,
        );

        AppLogger.info('VM stopped with exit code: $exitCode');
        _currentProcess = null;
        return true;
      } catch (e) {
        AppLogger.warning('Graceful shutdown failed: $e');
      }

      // Force kill if graceful shutdown failed
      if (_currentProcess != null) {
        bool killed = _currentProcess!.kill(ProcessSignal.sigkill);
        if (killed) {
          _currentProcess = null;
          AppLogger.info('VM force stopped');
          return true;
        }
      }

      return false;
    } catch (e) {
      AppLogger.error('Error stopping VM: $e');
      _currentProcess = null;
      return false;
    }
  }

  // Check if VM is currently running
  bool get isRunning => _currentProcess != null;

  // Get VM process ID if running
  int? get vmPid => _currentProcess?.pid;
}
