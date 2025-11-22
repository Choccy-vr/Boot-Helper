import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/responsive.dart';
import '../theme/terminal_theme.dart';
import '../Projects/Project.dart';
import '../vm/qemu_manager.dart';
import '../setup/Setup_Manager.dart' show DeepLinkManager;
import '../misc/app_settings.dart';
import 'package:file_picker/file_picker.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _typewriterController;
  late Animation<int> _typewriterAnimation;
  final String _welcomeText = "Boot Helper";
  final TextEditingController _projectIdController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _typewriterController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _typewriterAnimation = IntTween(begin: 0, end: _welcomeText.length).animate(
      CurvedAnimation(parent: _typewriterController, curve: Curves.easeInOut),
    );
    _typewriterController.forward();
    _checkAppConfiguration();
  }

  Future<void> _checkAppConfiguration() async {
    final isConfigured = await AppSettings.isAppConfigured();
    if (!isConfigured && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => SetupDeepLinksPage()),
      );
    }
  }

  @override
  void dispose() {
    _typewriterController.dispose();
    _projectIdController.dispose();
    super.dispose();
  }

  Future<void> _loadProject() async {
    final projectId = _projectIdController.text.trim();
    if (projectId.isEmpty) {
      setState(() => _errorMessage = 'Please enter a project ID');
      return;
    }

    final id = int.tryParse(projectId);
    if (id == null) {
      setState(() => _errorMessage = 'Invalid project ID');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // For now, create a mock project
    // TODO: Integrate with actual ProjectService when available
    final mockProject = Project(
      id: id,
      title: 'Project $id',
      description: 'Test project',
      reviewed: false,
      lastModified: DateTime.now(),
      imageURL: '',
      githubRepo: '',
      likes: 0,
      owner: 'user',
      createdAt: DateTime.now(),
      awaitingReview: false,
      level: 'beginner',
      status: 'active',
      timeDevlogs: 0,
      time: 0,
    );

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ProjectViewPage(project: mockProject),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: Responsive.pagePadding(context),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTerminalHeader(colorScheme, textTheme),
                    SizedBox(height: Responsive.spacing(context) * 2),
                    _buildProjectIdInput(colorScheme, textTheme),
                    SizedBox(height: Responsive.spacing(context)),
                    _buildActionButtons(colorScheme, textTheme),
                    if (_errorMessage != null) ...[
                      SizedBox(height: Responsive.spacing(context)),
                      _buildErrorMessage(colorScheme, textTheme),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTerminalHeader(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'boot ~ helper@local',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.primary),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _typewriterAnimation,
            builder: (context, child) {
              String displayText = _welcomeText.substring(
                0,
                _typewriterAnimation.value,
              );
              return RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '\$ ',
                      style: textTheme.headlineMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: displayText,
                      style: textTheme.headlineMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_typewriterAnimation.value == _welcomeText.length)
                      TextSpan(
                        text: '█',
                        style: textTheme.headlineMedium?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Test and Run OS Projects',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectIdInput(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_open, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Load Project',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _projectIdController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Project ID',
                hintText: 'Enter project ID to load',
                prefixIcon: Icon(Icons.tag),
                suffixIcon: _projectIdController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _projectIdController.clear();
                            _errorMessage = null;
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _errorMessage = null);
              },
              onSubmitted: (_) => _loadProject(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _loadProject,
          icon: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimary,
                  ),
                )
              : Icon(Icons.play_arrow),
          label: Text(_isLoading ? 'Loading...' : 'Load Project'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => SetupDeepLinksPage()),
            );
          },
          icon: Icon(Icons.settings),
          label: Text('Setup Deep Links'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorScheme.error),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectViewPage extends StatefulWidget {
  final Project project;

  const ProjectViewPage({super.key, required this.project});

  @override
  State<ProjectViewPage> createState() => _ProjectViewPageState();
}

class _ProjectViewPageState extends State<ProjectViewPage> {
  final QemuManager _qemuManager = QemuManager();
  bool _isRunning = false;
  String? _statusMessage;
  late TextEditingController _qemuCommandController;
  int? _isoFileSize;
  String? _isoFileName;
  String? _isoDestination;

  @override
  void initState() {
    super.initState();
    _qemuCommandController = TextEditingController(
      text: widget.project.qemuCMD,
    );
    _loadIsoInfo();
  }

  Future<void> _loadIsoInfo() async {
    final isoPath = widget.project.isoUrl;
    if (isoPath.isEmpty) return;

    // Extract filename from path or URL
    _isoFileName = isoPath.split('/').last.split('\\').last;

    // Get ISO download directory from settings
    final isoDir = await AppSettings.getIsoDownloadDirectory();

    // Check if it's a local file
    if (!isoPath.startsWith('http')) {
      final file = File(isoPath);
      if (await file.exists()) {
        final stat = await file.stat();
        setState(() {
          _isoFileSize = stat.size;
          _isoDestination = file.parent.path;
        });
      }
    } else {
      // For URLs, use the configured download directory
      setState(() {
        _isoDestination =
            isoDir ??
            '${Platform.environment['USERPROFILE'] ?? Platform.environment['HOME']}/Downloads';
      });
    }
  }

  @override
  void dispose() {
    _qemuCommandController.dispose();
    if (_isRunning) {
      _qemuManager.stopVM();
    }
    super.dispose();
  }

  Future<void> _runProject() async {
    final isoPath = widget.project.isoUrl.trim();
    final qemuCmd = _qemuCommandController.text.trim();

    if (isoPath.isEmpty) {
      setState(() {
        _statusMessage = 'No ISO URL configured for this project';
      });
      return;
    }

    if (qemuCmd.isEmpty) {
      setState(() {
        _statusMessage = 'No QEMU command configured';
      });
      return;
    }

    setState(() {
      _statusMessage = 'Starting VM...';
    });

    final success = await _qemuManager.startVMFromISO(isoPath, qemuCmd);

    setState(() {
      _isRunning = success;
      _statusMessage = success ? 'VM is running' : 'Failed to start VM';
    });
  }

  Future<void> _stopProject() async {
    final success = await _qemuManager.stopVM();
    setState(() {
      _isRunning = false;
      _statusMessage = success ? 'VM stopped' : 'Failed to stop VM';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerLowest,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Project ${widget.project.id}'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: Responsive.pagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProjectInfo(colorScheme, textTheme),
                SizedBox(height: Responsive.spacing(context)),
                _buildConfigurationCard(colorScheme, textTheme),
                SizedBox(height: Responsive.spacing(context)),
                _buildIsoInfoCard(colorScheme, textTheme),
                SizedBox(height: Responsive.spacing(context)),
                _buildSystemInfo(colorScheme, textTheme),
                SizedBox(height: Responsive.spacing(context)),
                _buildControlButtons(colorScheme, textTheme),
                if (_statusMessage != null) ...[
                  SizedBox(height: Responsive.spacing(context)),
                  _buildStatusMessage(colorScheme, textTheme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectInfo(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory, color: colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.project.title,
                    style: textTheme.headlineSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.project.description,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationCard(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Configuration',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              'Architecture',
              widget.project.architecture,
              Icons.computer,
              colorScheme,
              textTheme,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'ISO URL',
              widget.project.isoUrl.isNotEmpty
                  ? widget.project.isoUrl
                  : 'Not configured',
              Icons.disc_full,
              colorScheme,
              textTheme,
            ),
            const SizedBox(height: 16),
            Text(
              'QEMU Command (Editable)',
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _qemuCommandController,
              decoration: InputDecoration(
                hintText: 'QEMU command template',
                prefixIcon: Icon(Icons.code),
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              style: textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIsoInfoCard(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'ISO Information',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              'File Name',
              _isoFileName ?? 'Not set',
              Icons.insert_drive_file,
              colorScheme,
              textTheme,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'File Size',
              _isoFileSize != null
                  ? '${(_isoFileSize! / 1024 / 1024).toStringAsFixed(2)} MB'
                  : 'Unknown',
              Icons.sd_storage,
              colorScheme,
              textTheme,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Destination',
              _isoDestination ?? 'Not set',
              Icons.folder,
              colorScheme,
              textTheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colorScheme.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSystemInfo(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.computer, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'System Status',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusRow(
              'Operating System',
              _qemuManager.currentOS,
              Icons.desktop_windows,
              colorScheme,
              textTheme,
            ),
            const SizedBox(height: 12),
            FutureBuilder<bool>(
              future: _qemuManager.isQemuInstalled(),
              builder: (context, snapshot) {
                final isInstalled = snapshot.data ?? false;
                return _buildStatusRow(
                  'QEMU Status',
                  isInstalled ? 'Installed' : 'Not Installed',
                  Icons.check_circle,
                  colorScheme,
                  textTheme,
                  statusColor: isInstalled
                      ? TerminalColors.green
                      : TerminalColors.red,
                );
              },
            ),
            const SizedBox(height: 12),
            _buildStatusRow(
              'VM Status',
              _isRunning ? 'Running' : 'Stopped',
              Icons.power_settings_new,
              colorScheme,
              textTheme,
              statusColor: _isRunning
                  ? TerminalColors.green
                  : TerminalColors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(
    String label,
    String value,
    IconData icon,
    ColorScheme colorScheme,
    TextTheme textTheme, {
    Color? statusColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: statusColor ?? colorScheme.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            color: statusColor ?? colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isRunning)
          ElevatedButton.icon(
            onPressed: _runProject,
            icon: Icon(Icons.play_arrow),
            label: Text('Run Project'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: _stopProject,
            icon: Icon(Icons.stop),
            label: Text('Stop VM'),
            style: ElevatedButton.styleFrom(
              backgroundColor: TerminalColors.red,
              foregroundColor: TerminalColors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {},
          icon: Icon(Icons.info_outline),
          label: Text('Project Details'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusMessage(ColorScheme colorScheme, TextTheme textTheme) {
    final isError = _statusMessage!.toLowerCase().contains('failed');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? colorScheme.errorContainer
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isError ? colorScheme.error : colorScheme.primary,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            color: isError ? colorScheme.error : colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage!,
              style: textTheme.bodyMedium?.copyWith(
                color: isError
                    ? colorScheme.onErrorContainer
                    : colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SetupDeepLinksPage extends StatefulWidget {
  const SetupDeepLinksPage({super.key});

  @override
  State<SetupDeepLinksPage> createState() => _SetupDeepLinksPageState();
}

class _SetupDeepLinksPageState extends State<SetupDeepLinksPage> {
  bool _isConfigured = false;
  bool _isLoading = true;
  String? _statusMessage;
  final TextEditingController _qemuPathController = TextEditingController();
  final TextEditingController _isoDownloadDirController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _qemuPathController.dispose();
    _isoDownloadDirController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final configured = await DeepLinkManager.areDeepLinksConfigured();
    final qemuPath = await AppSettings.getQemuPath();
    final isoDir = await AppSettings.getIsoDownloadDirectory();

    setState(() {
      _isConfigured = configured;
      _qemuPathController.text = qemuPath ?? '';
      _isoDownloadDirController.text = isoDir ?? '';
      _isLoading = false;
    });
  }

  Future<void> _pickQemuPath() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: 'Select QEMU Executable',
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      _qemuPathController.text = path;
      await AppSettings.setQemuPath(path);
    }
  }

  Future<void> _pickIsoDownloadDirectory() async {
    String? result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select ISO Download Directory',
    );

    if (result != null) {
      _isoDownloadDirController.text = result;
      await AppSettings.setIsoDownloadDirectory(result);
    }
  }

  Future<void> _setupDeepLinks() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final exePath = Platform.resolvedExecutable;
    final success = await DeepLinkManager.setupDeepLinks(exePath);

    if (success) {
      await AppSettings.setDeepLinksConfigured(true);
    }

    setState(() {
      _isLoading = false;
      _isConfigured = success;
      _statusMessage = success
          ? 'Deep links configured successfully!'
          : 'Failed to configure deep links';
    });
  }

  Future<void> _saveAndContinue() async {
    // Validate settings
    if (_qemuPathController.text.trim().isEmpty) {
      setState(() => _statusMessage = 'Please set QEMU path');
      return;
    }

    if (_isoDownloadDirController.text.trim().isEmpty) {
      setState(() => _statusMessage = 'Please set ISO download directory');
      return;
    }

    if (!_isConfigured) {
      setState(() => _statusMessage = 'Please configure deep links first');
      return;
    }

    // Navigate to home page
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => HomePage()));
    }
  }

  Future<void> _removeDeepLinks() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final success = await DeepLinkManager.removeDeepLinks();

    setState(() {
      _isLoading = false;
      _isConfigured = !success;
      _statusMessage = success
          ? 'Deep links removed successfully!'
          : 'Failed to remove deep links';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerLowest,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Application Setup'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: Responsive.pagePadding(context),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(colorScheme, textTheme),
                    SizedBox(height: Responsive.spacing(context)),
                    _buildAppSettingsCard(colorScheme, textTheme),
                    SizedBox(height: Responsive.spacing(context)),
                    _buildStatusCard(colorScheme, textTheme),
                    SizedBox(height: Responsive.spacing(context)),
                    _buildInfoCard(colorScheme, textTheme),
                    SizedBox(height: Responsive.spacing(context)),
                    _buildActionButtons(colorScheme, textTheme),
                    if (_statusMessage != null) ...[
                      SizedBox(height: Responsive.spacing(context)),
                      _buildStatusMessage(colorScheme, textTheme),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Application Setup',
                  style: textTheme.headlineSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Configure application settings and deep links',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettingsCard(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Application Settings',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'QEMU Executable Path',
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _qemuPathController,
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Click to select QEMU executable',
                prefixIcon: Icon(Icons.terminal),
                suffixIcon: IconButton(
                  icon: Icon(Icons.folder_open),
                  onPressed: _pickQemuPath,
                ),
                border: OutlineInputBorder(),
              ),
              onTap: _pickQemuPath,
            ),
            const SizedBox(height: 16),
            Text(
              'ISO Download Directory',
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _isoDownloadDirController,
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Click to select directory',
                prefixIcon: Icon(Icons.folder),
                suffixIcon: IconButton(
                  icon: Icon(Icons.folder_open),
                  onPressed: _pickIsoDownloadDirectory,
                ),
                border: OutlineInputBorder(),
              ),
              onTap: _pickIsoDownloadDirectory,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ColorScheme colorScheme, TextTheme textTheme) {
    if (_isLoading) {
      return Card(
        color: colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isConfigured ? Icons.check_circle : Icons.cancel,
                  color: _isConfigured
                      ? TerminalColors.green
                      : TerminalColors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Status',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _isConfigured
                  ? 'Deep links are configured and active'
                  : 'Deep links are not configured',
              style: textTheme.bodyLarge?.copyWith(
                color: _isConfigured
                    ? TerminalColors.green
                    : TerminalColors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(ColorScheme colorScheme, TextTheme textTheme) {
    final qemuManager = QemuManager();
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'How It Works',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Deep links allow you to open Boot Helper projects directly from your browser using URLs like:',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Text(
                'boothelper://project=21',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Current platform: ${qemuManager.currentOS}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isConfigured)
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _setupDeepLinks,
            icon: _isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : Icon(Icons.add_link),
            label: Text('Configure Deep Links'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _removeDeepLinks,
            icon: Icon(Icons.link_off),
            label: Text('Remove Deep Links'),
            style: OutlinedButton.styleFrom(
              foregroundColor: TerminalColors.red,
              side: BorderSide(color: TerminalColors.red),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _saveAndContinue,
          icon: Icon(Icons.check),
          label: Text('Save & Continue'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: TerminalColors.green,
            foregroundColor: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusMessage(ColorScheme colorScheme, TextTheme textTheme) {
    final isError = _statusMessage!.toLowerCase().contains('failed');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? colorScheme.errorContainer
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isError ? colorScheme.error : colorScheme.primary,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? colorScheme.error : colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage!,
              style: textTheme.bodyMedium?.copyWith(
                color: isError
                    ? colorScheme.onErrorContainer
                    : colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
