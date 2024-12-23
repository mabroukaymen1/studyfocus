import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:study/home/activity.dart';
import 'package:study/home/activity_dailog.dart';
import 'package:study/home/education_card.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:sidebarx/sidebarx.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

import 'package:study/login/login.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pageController = PageController(initialPage: 0);
  final _activityService = ActivityService();
  StreamSubscription<List<Activity>>? _activitiesSubscription;
  late SidebarXController _sidebarController;

  int _selectedIndex = 0;
  String _searchQuery = '';
  String userName = "";
  List<Activity> activities = [];
  bool isLoading = true;
  String errorMessage = '';

  int lessonCount = 0;
  int taskCount = 0;
  int finishCount = 0;

  @override
  void initState() {
    super.initState();
    _sidebarController = SidebarXController(selectedIndex: 0, extended: true);
    _loadUserName();
    _subscribeToActivities();
    AwesomeNotifications().initialize(
      'resource://drawable/res_app_icon',
      [
        NotificationChannel(
          channelKey: 'basic_channel',
          channelName: 'Basic notifications',
          channelDescription: 'Notification channel for basic tests',
          defaultColor: Color(0xFF9D50DD),
          ledColor: Colors.white,
        )
      ],
    );
  }

  Future<void> _loadUserName() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && mounted) {
          setState(() {
            userName = userDoc['username'] ?? "User";
          });
        }
      } catch (e) {
        developer.log('Error loading username', error: e);
      }
    }
  }

  void _subscribeToActivities() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      _activitiesSubscription?.cancel();
      _activitiesSubscription =
          _activityService.streamUserActivities(user.uid).listen(
        (updatedActivities) {
          if (mounted) {
            setState(() {
              activities = updatedActivities;
              isLoading = false;
              _updateActivityCounts(updatedActivities);
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              errorMessage = error.toString().contains('failed-precondition')
                  ? 'Initializing data... Please wait a moment and try again.'
                  : 'Error loading activities. Please try again later.';
              isLoading = false;
            });
          }
          developer.log('Error in activities subscription', error: error);
        },
      );
    }
  }

  void _updateActivityCounts(List<Activity> activities) {
    setState(() {
      lessonCount =
          activities.where((a) => a.type == ActivityType.lesson).length;
      taskCount = activities.where((a) => a.type == ActivityType.task).length;
      finishCount = activities
          .where((a) => a.scheduledTime.isBefore(DateTime.now()))
          .length;
    });
  }

  @override
  void dispose() {
    _activitiesSubscription?.cancel();
    _pageController.dispose();
    _sidebarController.dispose();
    super.dispose();
  }

  void _showAddActivityDialog() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add activities')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddActivityDialog(
          onActivityAdded: (activity) async {
            try {
              await _activityService.addActivity(activity);
              scheduleActivityNotifications(
                  activity.scheduledTime, activity.type == ActivityType.exam);
              // Stream will handle the UI update
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to add activity: $e')),
                );
              }
            }
          },
        );
      },
    );
  }

  void _showDeleteActivityDialog(Activity activity) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Delete Activity',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: Text(
            'Are you sure you want to delete this activity?',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _activityService.deleteActivity(activity.id);
                  // The stream will automatically update the UI
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete activity: $e')),
                  );
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToPage(int index) {
    Navigator.pop(context); // Close drawer
    _pageController.jumpToPage(index);
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> scheduleNotification(
      DateTime scheduledTime, String title, String body) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 10,
        channelKey: 'basic_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar.fromDate(date: scheduledTime),
    );
  }

  void scheduleActivityNotifications(DateTime activityTime, bool isExam) {
    DateTime notificationTime = activityTime.subtract(Duration(minutes: 5));
    scheduleNotification(notificationTime, 'Activity Reminder',
        'Your activity starts in 5 minutes.');

    if (isExam) {
      DateTime examNotificationTime =
          activityTime.subtract(Duration(hours: 24));
      scheduleNotification(
          examNotificationTime, 'Exam Reminder', 'Your exam is in 24 hours.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: SidebarX(
        controller: _sidebarController,
        theme: SidebarXTheme(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            color: Colors.white70,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
          ),
          itemTextPadding: const EdgeInsets.only(left: 30),
          selectedItemTextPadding: const EdgeInsets.only(left: 30),
          itemDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.transparent),
          ),
          selectedItemDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.blue.withOpacity(0.37),
            ),
            gradient: const LinearGradient(
              colors: [Color(0xFF121212), Color(0xFF1E1E1E)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 30,
              )
            ],
          ),
          iconTheme: IconThemeData(
            color: Colors.white.withOpacity(0.7),
            size: 20,
          ),
          selectedIconTheme: const IconThemeData(
            color: Colors.blue,
            size: 20,
          ),
        ),
        extendedTheme: const SidebarXTheme(
          width: 200,
          decoration: BoxDecoration(
            color: Color(0xFF121212),
          ),
        ),
        footerDivider: Divider(color: Colors.white.withOpacity(0.3), height: 1),
        headerBuilder: (context, extended) {
          return SizedBox(
            height: 100,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Image.asset('assets/image/logo.png'),
            ),
          );
        },
        items: [
          SidebarXItem(
            icon: Icons.person,
            label: 'Profile',
            onTap: () => _navigateToPage(3),
          ),
          SidebarXItem(
            icon: Icons.list_alt,
            label: 'Activities',
            onTap: () => _navigateToPage(1),
          ),
          SidebarXItem(
            icon: Icons.chat,
            label: 'Chat',
            onTap: () => _navigateToPage(2),
          ),
          SidebarXItem(
            icon: Icons.settings,
            label: 'Settings',
            onTap: () {
              // Implement settings functionality
            },
          ),
          SidebarXItem(
            icon: Icons.logout,
            label: 'Sign Out',
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      appBar: AppBar(
        title: Text(
          "Home",
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        backgroundColor: const Color(0xFF121212),
      ),
      backgroundColor: const Color(0xFF121212),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(4, (index) => _buildPage(index)),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: const Color(0xFF121212),
        color: const Color(0xFF1E1E1E),
        buttonBackgroundColor: Colors.blue,
        animationDuration: const Duration(milliseconds: 500),
        height: 60,
        items: [
          SvgPicture.asset(
            'assets/image/home.svg',
            width: 30,
            height: 30,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          SvgPicture.asset(
            'assets/image/book.svg',
            width: 30,
            height: 30,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          SvgPicture.asset(
            'assets/image/bubble.svg',
            width: 30,
            height: 30,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          SvgPicture.asset(
            'assets/image/user.svg',
            width: 30,
            height: 30,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        },
      ),
    );
  }

  Widget _buildPage(int index) {
    if (index == 0) {
      return SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.white),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildSearchBar(),
                        const SizedBox(height: 20),
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildStatusSection(),
                        const SizedBox(height: 30),
                        _buildEducationSection(),
                        const SizedBox(height: 30),
                        _buildUpcomingSection(),
                      ],
                    ),
                  ),
      );
    } else if (index == 2) {
      return LoginPage();
    } else {
      return Center(
        child: Text(
          'Page ${index + 1}',
          style: const TextStyle(
            fontSize: 24,
            color: Colors.white,
          ),
        ),
      );
    }
  }

  Widget _buildSearchBar() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.blue,
      decoration: InputDecoration(
        hintText: 'Search...',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.6)),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formattedDate(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            Row(
              children: [
                Text(
                  'Hey, $userName ',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  '👋',
                  style: TextStyle(fontSize: 22),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  'Pursuing a bachelor\'s degree ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const Icon(Icons.school, color: Colors.blue, size: 16),
              ],
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withOpacity(0.1),
          ),
          padding: const EdgeInsets.all(8),
          child: const Icon(Icons.notifications, color: Colors.blue),
        )
      ],
    );
  }

  Widget _buildStatusCardAlt(String label, String value, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatusCard('Lesson', '$lessonCount', Colors.blue),
        _buildStatusCard('Task', '$taskCount', Colors.blue),
        _buildStatusCard('Finish', '$finishCount', Colors.green),
      ],
    );
  }

  Widget _buildStatusCard(String label, String value, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationSection() {
    final filteredActivities = _searchQuery.isEmpty
        ? activities
        : activities
            .where((activity) => activity.title
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
            .toList();

    return Column(
      children: [
        _buildSectionHeader('Education Schedule'),
        const SizedBox(height: 16),
        Row(
          children: [
            EducationCard(
              title: 'Add your education\nneeds here.',
              subtitle: 'Schedule of subjects, assignments and school exams.',
              icon: Icons.add,
              iconBgColor: Colors.white.withOpacity(0.1),
              onAddTap: _showAddActivityDialog,
            ),
            const SizedBox(width: 16),
            if (filteredActivities.isNotEmpty)
              EducationCard(
                title: filteredActivities[0].title,
                subtitle: _getSubtitleForActivity(filteredActivities[0]),
                icon: _getIconForActivity(filteredActivities[0].type),
                iconBgColor: Colors.blue.withOpacity(0.1),
                imagePath: 'assets/image/final.png',
                activity: filteredActivities[0],
                onDelete: () =>
                    _showDeleteActivityDialog(filteredActivities[0]),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (int i = 1; i < filteredActivities.length; i += 2) ...[
          Row(
            children: [
              EducationCard(
                title: filteredActivities[i].title,
                subtitle: _getSubtitleForActivity(filteredActivities[i]),
                icon: _getIconForActivity(filteredActivities[i].type),
                iconBgColor: Colors.blue.withOpacity(0.1),
                imagePath: 'assets/image/final.png',
                activity: filteredActivities[i],
                onDelete: () =>
                    _showDeleteActivityDialog(filteredActivities[i]),
              ),
              const SizedBox(width: 16),
              if (i + 1 < filteredActivities.length)
                EducationCard(
                  title: filteredActivities[i + 1].title,
                  subtitle: _getSubtitleForActivity(filteredActivities[i + 1]),
                  icon: _getIconForActivity(filteredActivities[i + 1].type),
                  iconBgColor: Colors.blue.withOpacity(0.1),
                  imagePath: 'assets/image/final.png',
                  activity: filteredActivities[i + 1],
                  onDelete: () =>
                      _showDeleteActivityDialog(filteredActivities[i + 1]),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  IconData _getIconForActivity(ActivityType type) {
    switch (type) {
      case ActivityType.lesson:
        return Icons.book;
      case ActivityType.task:
        return Icons.assignment;
      case ActivityType.exam:
        return Icons.edit_note;
      default:
        return Icons.event;
    }
  }

  String _getSubtitleForActivity(Activity activity) {
    switch (activity.type) {
      case ActivityType.lesson:
        return 'Theory';
      case ActivityType.task:
        return 'Assignment';
      case ActivityType.exam:
        return 'Examination';
      default:
        return 'Activity';
    }
  }

  Widget _buildUpcomingSection() {
    final today = DateTime.now();
    final upcomingActivities = activities.where((activity) {
      return activity.scheduledTime.year == today.year &&
          activity.scheduledTime.month == today.month &&
          activity.scheduledTime.day == today.day;
    }).toList();

    return Column(
      children: [
        _buildSectionHeader('Upcoming Schedule'),
        const SizedBox(height: 16),
        if (upcomingActivities.isEmpty)
          const Text(
            'No upcoming activities for today.',
            style: TextStyle(color: Colors.white),
          )
        else
          for (var activity in upcomingActivities)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/image/mang.png',
                      height: 60,
                      width: 60,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Colors.white.withOpacity(0.6),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${activity.scheduledTime.hour}:${activity.scheduledTime.minute}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        TextButton(
          onPressed: () {
            // Handle View All
          },
          child: const Text(
            'View All',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue,
            ),
          ),
        )
      ],
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    return '${now.day} ${_getMonthName(now.month)}, ${now.year}';
  }

  String _getMonthName(int month) {
    return _months[month - 1];
  }

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
}
