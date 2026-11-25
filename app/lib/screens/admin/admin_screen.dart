import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/ios_theme.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;
  Map<String, dynamic> _stats = {};
  List<dynamic> _users = [];
  List<dynamic> _hubRequests = [];
  List<dynamic> _publicHubs = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllAdminData() async {
    setState(() => _loading = true);
    try {
      final statsRes = await ApiService.instance.getAdminStats();
      if (statsRes['success'] == true) {
        _stats = statsRes['data'] ?? {};
      }

      final usersRes = await ApiService.instance.getAdminUsers(query: _searchController.text.trim());
      if (usersRes['success'] == true) {
        _users = usersRes['data'] ?? [];
      }

      final requestsRes = await ApiService.instance.getAdminHubRequests();
      if (requestsRes['success'] == true) {
        _hubRequests = requestsRes['data'] ?? [];
      }

      final hubsRes = await ApiService.instance.getPublicHubs();
      if (hubsRes['success'] == true) {
        _publicHubs = hubsRes['data'] ?? [];
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleSuspend(String userId, String userName, bool currentStatus) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(currentStatus ? 'Unsuspend User?' : 'Suspend User?', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to ${currentStatus ? 'unsuspend' : 'suspend'} $userName?',
          style: TextStyle(color: secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: secondaryTextColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus ? IosTheme.primaryGreen : Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(currentStatus ? 'Unsuspend' : 'Suspend', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await ApiService.instance.adminToggleSuspend(userId);
    if (mounted) {
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Status updated'), backgroundColor: IosTheme.primaryGreen),
        );
        _loadAllAdminData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Action failed'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);

    final userId = user['id'].toString();
    final nameCtrl = TextEditingController(text: user['display_name'] ?? '');
    final numCtrl = TextEditingController(text: user['full_number'] ?? '');
    final phoneCtrl = TextEditingController(text: user['phone'] ?? '');
    final emailCtrl = TextEditingController(text: user['email'] ?? '');
    final passCtrl = TextEditingController(); // Empty by default
    bool isAdminVal = user['is_admin'] == true;
    bool isSuspendedVal = user['is_suspended'] == true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.manage_accounts, color: IosTheme.primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Edit User: ${user['display_name'] ?? 'User'}',
                  style: TextStyle(color: primaryTextColor, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: primaryTextColor),
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    labelStyle: TextStyle(color: secondaryTextColor),
                    prefixIcon: const Icon(Icons.person, color: IosTheme.accentBlue),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: numCtrl,
                  style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'IntraCom Number',
                    labelStyle: TextStyle(color: secondaryTextColor),
                    prefixIcon: const Icon(Icons.dialpad, color: IosTheme.primaryGreen),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  style: TextStyle(color: primaryTextColor),
                  decoration: InputDecoration(
                    labelText: 'Mobile Phone',
                    labelStyle: TextStyle(color: secondaryTextColor),
                    prefixIcon: Icon(Icons.phone_android, color: secondaryTextColor),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  style: TextStyle(color: primaryTextColor),
                  decoration: InputDecoration(
                    labelText: 'Email Address (Optional)',
                    labelStyle: TextStyle(color: secondaryTextColor),
                    prefixIcon: Icon(Icons.email, color: secondaryTextColor),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  style: TextStyle(color: primaryTextColor),
                  decoration: InputDecoration(
                    labelText: 'Reset Password (Leave blank to keep current)',
                    labelStyle: TextStyle(color: secondaryTextColor),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.orangeAccent),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Admin Privileges', style: TextStyle(color: primaryTextColor, fontSize: 14)),
                  subtitle: Text('Grant full admin control', style: TextStyle(color: secondaryTextColor, fontSize: 11)),
                  value: isAdminVal,
                  activeTrackColor: Colors.amber,
                  onChanged: (val) => setDlgState(() => isAdminVal = val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Suspend Account', style: TextStyle(color: primaryTextColor, fontSize: 14)),
                  subtitle: Text('Block calls and app access', style: TextStyle(color: secondaryTextColor, fontSize: 11)),
                  value: isSuspendedVal,
                  activeTrackColor: Colors.redAccent,
                  onChanged: (val) => setDlgState(() => isSuspendedVal = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: secondaryTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: IosTheme.primaryGreen),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);

                final updateData = <String, dynamic>{
                  'display_name': nameCtrl.text.trim(),
                  'full_number': numCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'is_admin': isAdminVal,
                  'is_suspended': isSuspendedVal,
                };
                if (passCtrl.text.trim().isNotEmpty) {
                  updateData['password'] = passCtrl.text.trim();
                }

                final res = await ApiService.instance.adminUpdateUserFull(userId, updateData);
                if (res['success'] == true) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('User information updated successfully!'),
                      backgroundColor: IosTheme.primaryGreen,
                    ),
                  );
                  _loadAllAdminData();
                  // If the admin edited their own account, refresh the profile
                  final myNum = ApiService.instance.currentUser?['full_number'];
                  if (myNum == user['full_number'] || myNum == numCtrl.text.trim()) {
                    await ApiService.instance.getProfile();
                  }
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(res['error'] ?? 'Update failed'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewHubRequest(String requestId, String action, String hubName) async {
    String note = '';
    if (action == 'reject') {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
      final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);
      final noteCtrl = TextEditingController();
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Reject Hub Request', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: noteCtrl,
            style: TextStyle(color: primaryTextColor),
            decoration: InputDecoration(
              hintText: 'Reason for rejection (optional)',
              hintStyle: TextStyle(color: secondaryTextColor),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: secondaryTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      note = noteCtrl.text.trim();
    }

    final res = await ApiService.instance.adminReviewHubRequest(requestId, action, note: note);
    if (mounted) {
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Reviewed'), backgroundColor: IosTheme.primaryGreen),
        );
        _loadAllAdminData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Error'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showManualAddUserSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final inputBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: '123456');
    int selectedDistrict = 1; // Default Dhaka (+1)

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Manual User Registration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: Icon(Icons.close, color: secondaryTextColor)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: primaryTextColor),
                      decoration: InputDecoration(labelText: 'Full Name *', labelStyle: TextStyle(color: secondaryTextColor), prefixIcon: Icon(Icons.person_outline, color: secondaryTextColor)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneCtrl,
                      style: TextStyle(color: primaryTextColor),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(labelText: 'Mobile Phone *', labelStyle: TextStyle(color: secondaryTextColor), prefixIcon: Icon(Icons.phone_outlined, color: secondaryTextColor)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      style: TextStyle(color: primaryTextColor),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: 'Email (Optional)', labelStyle: TextStyle(color: secondaryTextColor), prefixIcon: Icon(Icons.email_outlined, color: secondaryTextColor)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passCtrl,
                      style: TextStyle(color: primaryTextColor),
                      decoration: InputDecoration(labelText: 'Password *', labelStyle: TextStyle(color: secondaryTextColor), prefixIcon: Icon(Icons.lock_outline, color: secondaryTextColor)),
                    ),
                    const SizedBox(height: 14),
                    Text('Assign District (+Area Code):', style: TextStyle(color: secondaryTextColor, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: selectedDistrict,
                      dropdownColor: Theme.of(context).cardColor,
                      style: TextStyle(color: primaryTextColor),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Dhaka (+1)')),
                        DropdownMenuItem(value: 2, child: Text('Gazipur (+2)')),
                        DropdownMenuItem(value: 3, child: Text('Narayanganj (+3)')),
                        DropdownMenuItem(value: 15, child: Text('Chittagong (+15)')),
                        DropdownMenuItem(value: 16, child: Text('Cox\'s Bazar (+16)')),
                        DropdownMenuItem(value: 26, child: Text('Sylhet (+26)')),
                        DropdownMenuItem(value: 30, child: Text('Rajshahi (+30)')),
                        DropdownMenuItem(value: 39, child: Text('Khulna (+39)')),
                        DropdownMenuItem(value: 49, child: Text('Barisal (+49)')),
                        DropdownMenuItem(value: 55, child: Text('Rangpur (+55)')),
                        DropdownMenuItem(value: 63, child: Text('Mymensingh (+63)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => selectedDistrict = val);
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: IosTheme.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Please fill all required fields')),
                            );
                            return;
                          }
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(ctx);
                          final res = await ApiService.instance.register(
                            name: nameCtrl.text.trim(),
                            email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            password: passCtrl.text.trim(),
                            districtCode: selectedDistrict,
                          );
                          if (res['success'] == true) {
                            final num = res['data']?['full_number'];
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('User created successfully! Assigned: $num'),
                                backgroundColor: IosTheme.primaryGreen,
                              ),
                            );
                            _loadAllAdminData();
                          } else {
                            messenger.showSnackBar(
                              SnackBar(content: Text(res['error'] ?? 'Creation failed'), backgroundColor: Colors.redAccent),
                            );
                          }
                        },
                        child: const Text('Create User', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showBanUserDialog(String hubId, String hubName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final numCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Ban User from "$hubName"', style: TextStyle(color: primaryTextColor, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numCtrl,
              style: TextStyle(color: primaryTextColor),
              decoration: InputDecoration(
                labelText: 'Target User Number (e.g. +1-2985297)',
                labelStyle: TextStyle(color: secondaryTextColor),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              style: TextStyle(color: primaryTextColor),
              decoration: InputDecoration(
                labelText: 'Ban Reason',
                labelStyle: TextStyle(color: secondaryTextColor),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: secondaryTextColor))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              if (numCtrl.text.trim().isEmpty) return;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final res = await ApiService.instance.adminBanUserFromHub(hubId, numCtrl.text.trim(), reason: reasonCtrl.text.trim());
              messenger.showSnackBar(
                SnackBar(
                  content: Text(res['message'] ?? res['error'] ?? 'Executed'),
                  backgroundColor: res['success'] == true ? IosTheme.primaryGreen : Colors.redAccent,
                ),
              );
            },
            child: const Text('Ban User', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Control Panel', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? Colors.white70 : const Color(0xFF3A3A3C)),
            onPressed: _loadAllAdminData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: IosTheme.primaryGreen,
          labelColor: IosTheme.primaryGreen,
          unselectedLabelColor: isDark ? Colors.white54 : const Color(0xFF8E8E93),
          tabs: [
            Tab(text: 'Users (${_users.length})'),
            Tab(text: 'Hub Requests (${_hubRequests.where((r) => r['status'] == 'pending').length})'),
            Tab(text: 'Moderation (${_publicHubs.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: IosTheme.primaryGreen))
          : Column(
              children: [
                _buildStatsHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUsersTab(),
                      _buildHubRequestsTab(),
                      _buildModerationTab(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: IosTheme.primaryGreen,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Add User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _showManualAddUserSheet,
            )
          : null,
    );
  }

  Widget _buildStatsHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final headerBorder = isDark ? Colors.white10 : const Color(0xFFE5E5EA);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: headerBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Users', '${_stats['total_users'] ?? _users.length}', primaryTextColor),
          _buildStatItem('Active', '${_stats['active_users'] ?? _users.where((u) => u['is_suspended'] != true).length}', IosTheme.primaryGreen),
          _buildStatItem('Suspended', '${_stats['suspended_users'] ?? _users.where((u) => u['is_suspended'] == true).length}', Colors.redAccent),
          _buildStatItem('Pending Hubs', '${_stats['pending_requests'] ?? _hubRequests.where((r) => r['status'] == 'pending').length}', Colors.amber),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF8E8E93))),
      ],
    );
  }

  Widget _buildUsersTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final cardBorder = isDark ? Colors.white10 : const Color(0xFFE5E5EA);
    final avatarBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: primaryTextColor),
            decoration: InputDecoration(
              hintText: 'Search by name, number, or phone...',
              hintStyle: TextStyle(color: secondaryTextColor),
              prefixIcon: Icon(Icons.search, color: secondaryTextColor),
              suffixIcon: IconButton(
                icon: Icon(Icons.clear, color: secondaryTextColor),
                onPressed: () {
                  _searchController.clear();
                  _loadAllAdminData();
                },
              ),
              filled: true,
              fillColor: cardBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onSubmitted: (_) => _loadAllAdminData(),
          ),
        ),
        Expanded(
          child: _users.isEmpty
              ? Center(child: Text('No users found', style: TextStyle(color: secondaryTextColor)))
              : ListView.builder(
                  itemCount: _users.length,
                  padding: const EdgeInsets.only(bottom: 80),
                  itemBuilder: (ctx, i) {
                    final u = _users[i];
                    final isSuspended = u['is_suspended'] == true;
                    final isAdmin = u['is_admin'] == true;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSuspended ? Colors.redAccent.withValues(alpha: 0.3) : cardBorder),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: isSuspended ? Colors.red.withValues(alpha: 0.2) : avatarBg,
                            child: Icon(
                              isAdmin ? Icons.admin_panel_settings : Icons.person,
                              color: isSuspended ? Colors.redAccent : (isAdmin ? Colors.amber : (isDark ? Colors.white70 : const Color(0xFF1C1C1E))),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      u['display_name'] ?? 'User',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryTextColor),
                                    ),
                                    if (isAdmin) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('ADMIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      u['full_number'],
                                      style: const TextStyle(fontSize: 14, color: IosTheme.primaryGreen, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _showEditUserDialog(u),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: IosTheme.primaryGreen.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: IosTheme.primaryGreen.withValues(alpha: 0.5)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit, size: 11, color: IosTheme.primaryGreen),
                                            SizedBox(width: 4),
                                            Text('Edit User', style: TextStyle(fontSize: 11, color: IosTheme.primaryGreen, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Area: ${u['district_name'] ?? ''} • Phone: ${u['phone']} ${u['email'] != '' ? '• ${u['email']}' : ''}',
                                  style: TextStyle(fontSize: 11, color: secondaryTextColor),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                isSuspended ? 'SUSPENDED' : 'ACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSuspended ? Colors.redAccent : IosTheme.primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSuspended ? IosTheme.primaryGreen : Colors.redAccent.withValues(alpha: 0.8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: const Size(60, 28),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _toggleSuspend(u['id'], u['display_name'] ?? 'User', isSuspended),
                                child: Text(
                                  isSuspended ? 'Unsuspend' : 'Suspend',
                                  style: const TextStyle(fontSize: 11, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHubRequestsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final descTextColor = isDark ? Colors.white70 : const Color(0xFF3A3A3C);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final cardBorder = isDark ? Colors.white10 : const Color(0xFFE5E5EA);

    if (_hubRequests.isEmpty) {
      return Center(child: Text('No hub requests found', style: TextStyle(color: secondaryTextColor)));
    }
    return ListView.builder(
      itemCount: _hubRequests.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemBuilder: (ctx, i) {
        final req = _hubRequests[i];
        final status = req['status'] ?? 'pending';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      req['name'] ?? 'Untitled Hub',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryTextColor),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: status == 'approved'
                          ? IosTheme.primaryGreen.withValues(alpha: 0.2)
                          : (status == 'rejected' ? Colors.red.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: status == 'approved'
                            ? IosTheme.primaryGreen
                            : (status == 'rejected' ? Colors.redAccent : Colors.amber),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(req['description'] ?? 'No description', style: TextStyle(fontSize: 13, color: descTextColor)),
              const SizedBox(height: 8),
              Text(
                'Requester: ${req['requester_name']} (${req['requester_num']}) • Area: ${req['district_name']}',
                style: TextStyle(fontSize: 11, color: secondaryTextColor),
              ),
              if (status == 'pending') ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _reviewHubRequest(req['id'], 'reject', req['name'] ?? ''),
                      child: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IosTheme.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _reviewHubRequest(req['id'], 'approve', req['name'] ?? ''),
                      child: const Text('Approve & Activate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildModerationTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final descTextColor = isDark ? Colors.white70 : const Color(0xFF3A3A3C);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final cardBorder = isDark ? Colors.white10 : const Color(0xFFE5E5EA);

    if (_publicHubs.isEmpty) {
      return Center(child: Text('No active public hubs to moderate', style: TextStyle(color: secondaryTextColor)));
    }
    return ListView.builder(
      itemCount: _publicHubs.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemBuilder: (ctx, i) {
        final hub = _publicHubs[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    hub['name'] ?? 'Public Hub',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryTextColor),
                  ),
                  Text(
                    '${hub['member_count'] ?? 0} members',
                    style: const TextStyle(fontSize: 12, color: IosTheme.accentBlue),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(hub['description'] ?? '', style: TextStyle(fontSize: 13, color: descTextColor)),
              const SizedBox(height: 6),
              Text('Owner: ${hub['owner_name']} • Region: ${hub['district_name']}', style: TextStyle(fontSize: 11, color: secondaryTextColor)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.block, size: 14, color: Colors.redAccent),
                    label: const Text('Ban User from Hub', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    onPressed: () => _showBanUserDialog(hub['id'], hub['name'] ?? 'Hub'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
