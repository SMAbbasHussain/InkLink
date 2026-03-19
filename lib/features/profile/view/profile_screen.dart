import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inklink/domain/repositories/profile/profile_repository.dart';
import 'package:inklink/features/profile/bloc/profile_bloc.dart';
import 'package:inklink/features/profile/view/widgets/edit_profile_sheet.dart';
import '../../../core/constants/app_colors.dart';
import '../../friends/bloc/friends_bloc.dart';
import '../../friends/bloc/friends_event.dart';

class ProfileScreen extends StatelessWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // If we somehow got here without a UID, don't crash the bloc
    if (userId.isEmpty) {
      return const Scaffold(body: Center(child: Text("Invalid User ID")));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (context) =>
          ProfileBloc(profileRepo: context.read<ProfileRepository>())
            ..add(LoadProfile(userId)),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            BlocBuilder<ProfileBloc, ProfileState>(
              builder: (context, state) {
                if (state is ProfileLoaded && state.isSelf) {
                  return IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      // Use the extracted widget
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => BlocProvider.value(
                          value: context
                              .read<
                                ProfileBloc
                              >(), // Pass the bloc to the sheet
                          child: EditProfileSheet(userData: state.userData),
                        ),
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        extendBodyBehindAppBar: true,
        body: BlocBuilder<ProfileBloc, ProfileState>(
          builder: (context, state) {
            if (state is ProfileLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ProfileError) {
              return Center(child: Text(state.message));
            }
            if (state is ProfileLoaded) {
              final user = state.userData;
              return Column(
                children: [
                  _buildHeader(user, isDark),
                  const SizedBox(height: 24),
                  _buildBioSection(user, isDark),
                  const Spacer(),
                  _buildActionButtons(context, state, isDark),
                  const SizedBox(height: 40),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> user, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 100, 24, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A1A2E), Colors.black]
              : [AppColors.primary.withOpacity(0.1), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              ),
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: isDark
                  ? AppColors.surfaceDark
                  : Colors.grey.shade200,
              backgroundImage:
                  (user['photoURL'] != null &&
                      user['photoURL'].toString().isNotEmpty)
                  ? NetworkImage(user['photoURL'])
                  : null,
              child:
                  (user['photoURL'] == null ||
                      user['photoURL'].toString().isEmpty)
                  ? const Icon(Icons.person, size: 60)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user['displayName'] ?? "User",
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          Text(
            user['email'] ?? "",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildBioSection(Map<String, dynamic> user, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Bio",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              user['bio'] ??
                  "No bio yet. This creator is busy bringing ideas to life!",
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    ProfileLoaded state,
    bool isDark,
  ) {
    if (state.isSelf) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: InkWell(
        onTap: () {
          if (state.isFriend) {
            // Add Navigation to Chat later
          } else {
            // Use the specific userId passed to the widget
            context.read<FriendsBloc>().add(SendFriendRequestRequested(userId));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Request Sent!")));
          }
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: state.isFriend
                  ? [const Color(0xFF6A11CB), const Color(0xFF2575FC)]
                  : [const Color(0xFFFF5F6D), const Color(0xFFFFC371)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                state.isFriend ? Icons.chat_rounded : Icons.person_add_alt_1,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Text(
                state.isFriend ? "Message" : "Collaborate",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
