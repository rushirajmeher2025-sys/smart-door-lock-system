import 'dart:async';
import 'package:flutter/material.dart';
import '../models/access_request.dart';
import '../repositories/lock_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/backdrop.dart';
import '../widgets/panel.dart';
import '../widgets/screen_header.dart';
import '../widgets/settings_group.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final LockRepository _repository = lockRepository();
  StreamSubscription<List<AccessRequest>>? _requestsSub;
  List<AccessRequest> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _pendingRequests = _repository.currentPendingRequests;
    _requestsSub = _repository.pendingRequestsStream.listen((reqs) {
      if (mounted) setState(() => _pendingRequests = reqs);
    });
  }

  @override
  void dispose() {
    _requestsSub?.cancel();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _approve(AccessRequest req) async {
    try {
      await _repository.approveRequest(req.uid);
      _toast('Approved access for ${req.email}');
    } catch (e) {
      _toast('Failed to approve: $e');
    }
  }

  Future<void> _reject(AccessRequest req) async {
    try {
      await _repository.rejectRequest(req.uid);
      _toast('Declined access request from ${req.email}');
    } catch (e) {
      _toast('Failed to decline: $e');
    }
  }

  Future<void> _revoke(String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_remove_rounded, color: AppColors.alarm, size: 22),
            SizedBox(width: 10),
            Text('Revoke Access?'),
          ],
        ),
        content: Text(
          'Remove access for user "$uid"?\n\nThey will immediately be disconnected from this lock.',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.alarm),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoke Access'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.setMember(uid, false);
        _toast('Access revoked for user.');
      } catch (e) {
        _toast('Failed to revoke access: $e');
      }
    }
  }

  Future<void> _addMemberDialog() async {
    final controller = TextEditingController();
    final uid = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: AppColors.brand, size: 22),
            SizedBox(width: 10),
            Text('Grant Member Access'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the Firebase User ID (UID) of the person you want to give access to.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: AppTheme.mono(fontSize: 13, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'User ID',
                prefixIcon: Icon(Icons.fingerprint_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Grant Access')),
        ],
      ),
    );

    if (uid != null && uid.isNotEmpty) {
      try {
        await _repository.setMember(uid, true);
        _toast('Access granted to user');
      } catch (e) {
        _toast('Failed to grant access: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Backdrop(
        child: SafeArea(
          bottom: false,
          child: ValueListenableBuilder<LockAccess>(
            valueListenable: _repository.access,
            builder: (context, access, _) {
              final members = access.members.keys.toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                children: [
                  ScreenHeader(
                    title: 'Members & Access',
                    subtitle: 'Owner Portal · ${_repository.activeDeviceName}',
                  ),
                  const SizedBox(height: 18),

                  // Portal Info Banner
                  Panel(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.brand, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text(
                                    'OWNER ACCESS CONTROL',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      letterSpacing: 0.3,
                                      color: AppColors.brand,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Manage who can lock and unlock "${_repository.activeDeviceName}".',
                                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Pending Requests Section
                  const SizedBox(height: 24),
                  SettingsGroup(
                    title: 'Pending Requests (${_pendingRequests.length})',
                    footer: _pendingRequests.isEmpty
                        ? 'Users who request access to this lock will appear here for your approval.'
                        : 'Approved users will immediately gain access to control this door.',
                    children: [
                      if (_pendingRequests.isEmpty)
                        const ListTile(
                          leading: Icon(Icons.check_circle_outline_rounded, color: AppColors.textMuted),
                          title: Text('No pending requests', style: TextStyle(color: AppColors.textSecondary)),
                          subtitle: Text('All requests have been addressed'),
                        )
                      else
                        for (final req in _pendingRequests)
                          ListTile(
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_add_rounded, color: AppColors.warning, size: 20),
                            ),
                            title: Text(req.email, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                            subtitle: Text('Requested ${agoShort(req.requestedAt)}', style: AppTheme.mono(fontSize: 11, color: AppColors.textMuted)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 24),
                                  tooltip: 'Approve',
                                  onPressed: () => _approve(req),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel_rounded, color: AppColors.alarm, size: 24),
                                  tooltip: 'Decline',
                                  onPressed: () => _reject(req),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),

                  // Authorized Members Section
                  const SizedBox(height: 24),
                  SettingsGroup(
                    title: 'Authorized Members (${members.length})',
                    footer: 'Members can lock and unlock the door using their LocKify app.',
                    children: [
                      if (members.isEmpty)
                        const ListTile(
                          leading: Icon(Icons.group_outlined, color: AppColors.textMuted),
                          title: Text('No members added yet', style: TextStyle(color: AppColors.textSecondary)),
                          subtitle: Text('Invite family, roommates, or guests'),
                        )
                      else
                        for (final uid in members)
                          ListTile(
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.hairline),
                              ),
                              child: const Icon(Icons.person_outline_rounded, size: 20),
                            ),
                            title: Text(uid, overflow: TextOverflow.ellipsis, style: AppTheme.mono(fontSize: 12.5)),
                            subtitle: const Row(
                              children: [
                                Icon(Icons.verified_rounded, size: 12, color: AppColors.brand),
                                SizedBox(width: 4),
                                Text('Active Member', style: TextStyle(fontSize: 11.5, color: AppColors.brand)),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.alarm),
                              tooltip: 'Revoke Access',
                              onPressed: () => _revoke(uid),
                            ),
                          ),
                      ListTile(
                        leading: const Icon(Icons.person_add_alt_rounded, color: AppColors.brand),
                        title: const Text('Add member by User ID', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Instantly grant access by typing their UID'),
                        onTap: _addMemberDialog,
                      ),
                    ],
                  ),

                  // How to Invite Instructions
                  const SizedBox(height: 24),
                  Panel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.share_outlined, color: AppColors.brand, size: 20),
                            SizedBox(width: 8),
                            Text('How to Invite Family or Guests', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '1. Ask them to download the LocKify app and create an account.\n'
                          '2. In the lock list, they tap on "${_repository.activeDeviceName}" and select "Request Access".\n'
                          '3. You will receive an instant notification here in your Owner Portal to approve them with 1 tap.',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
