// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get profileTitle => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get alerts => 'Alert Notifications';

  @override
  String get language => 'Language';

  @override
  String get about => 'About';

  @override
  String get appVersion => 'App Version';

  @override
  String get ahaGuidelines => 'AHA 2020 Guidelines';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get logout => 'Log Out';

  @override
  String get totalSessions => 'Total sessions';

  @override
  String get averageScore => 'Overall Average';

  @override
  String get practiceHours => 'Practice Hours';

  @override
  String get currentStreak => 'Current Streak';

  @override
  String get student => 'STUDENT';

  @override
  String get instructor => 'INSTRUCTOR';

  @override
  String get admin => 'ADMIN';

  @override
  String get user => 'User';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get loginTitle => 'Log In';

  @override
  String get loginSubtitle => 'CPR Training System';

  @override
  String get loginInstruction => 'Enter with your institutional email';

  @override
  String get emailLabel => 'Email Address';

  @override
  String get emailHint => 'user@siercp.edu.co';

  @override
  String get passwordLabel => 'Password';

  @override
  String get forgotPassword => 'Forgot your password?';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register here';

  @override
  String get loginErrorEmptyFields => 'Enter your email and password';

  @override
  String get forgotPassErrorEmpty => 'Enter your email to reset your password.';

  @override
  String get forgotPassSuccess => '📧 Reset email sent.';

  @override
  String get registerTitle => 'Create Account';

  @override
  String get registerSubtitle => 'Join SIERCP and start your training';

  @override
  String get roleStudentLabel => 'Student';

  @override
  String get roleInstructorLabel => 'Instructor';

  @override
  String get firstName => 'First Name';

  @override
  String get lastName => 'Last Name';

  @override
  String get idLabel => 'ID Number';

  @override
  String get idHint => 'Ex: 1234567890';

  @override
  String get requiredField => 'Required';

  @override
  String get min5Digits => 'Minimum 5 digits';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get min6Chars => 'Minimum 6 characters';

  @override
  String get acceptPrivacy1 => 'I accept the ';

  @override
  String get acceptPrivacy2 => 'Privacy Policy';

  @override
  String get registerPrivacyError => 'You must accept the Privacy Policy';

  @override
  String get closeButton => 'Close';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navUsers => 'Users';

  @override
  String get navDevices => 'Manikins';

  @override
  String get navProfile => 'Profile';

  @override
  String get navHome => 'Home';

  @override
  String get navSession => 'Session';

  @override
  String get navHistory => 'History';

  @override
  String get navCourses => 'Courses';

  @override
  String get coursesTitle => 'Courses';

  @override
  String get searchingDevice => 'Searching...';

  @override
  String get deviceError => 'Error';

  @override
  String get noDevice => 'No manikin';

  @override
  String get searchingManikin => 'Searching manikin...';

  @override
  String get manikinNotDetected =>
      '⚠️ Manikin not detected. Check ESP32 connection.';

  @override
  String get adminDashboardTitle => 'Control Panel';

  @override
  String welcomeName(String name) {
    return 'Welcome, $name';
  }

  @override
  String get adminSubtitle => 'SIERCP Administrator';

  @override
  String get instructorSubtitle => 'Instructor';

  @override
  String get studentSubtitle => 'STUDENT';

  @override
  String get historicalSummary => 'Historical Summary';

  @override
  String get sessionsToday => 'Sessions Today';

  @override
  String get avgDepth => 'Avg. Depth';

  @override
  String get avgRate => 'Avg. Rate';

  @override
  String get compressionScore => 'Compressions OK %';

  @override
  String get depthHint => 'Range: 50–60mm';

  @override
  String get rateHint => 'Goal: 100–120';

  @override
  String get scoreHint => 'Goal: 85%+';

  @override
  String get courseProgress => 'Course Progress';

  @override
  String get systemAlerts => 'System Alerts';

  @override
  String get latestAlerts => 'Latest Alerts';

  @override
  String get noRecentAlerts => 'No recent alerts.';

  @override
  String get adminUsersSub => 'Instructors and Students';

  @override
  String get adminDevicesSub => 'Connection status';

  @override
  String get adminCoursesSub => 'Manage programs';

  @override
  String get adminReportsSub => 'Global statistics';

  @override
  String get newCourse => 'New Course';

  @override
  String get myStudents => 'My Students';

  @override
  String get exportData => 'Export';

  @override
  String get myActiveCourses => 'My active courses';

  @override
  String get viewAll => 'View all';

  @override
  String get noCoursesCreated =>
      'You haven\'t created any courses yet. Create the first one.';

  @override
  String get noCoursesCreatedPlain => 'You haven\'t created any courses yet';

  @override
  String get noCoursesJoinedPlain => 'You are not enrolled in any course';

  @override
  String get noCoursesCreatedDesc =>
      'Create your first course to start managing students.';

  @override
  String get noCoursesJoinedDesc =>
      'Ask your instructor for the code to join or wait to be enrolled.';

  @override
  String get createFirstCourseBtn => 'Create first course';

  @override
  String get joinWithCodeBtn => 'Join with code';

  @override
  String get joinCourseBtn => 'Join course';

  @override
  String get joinCourseTitle => 'Join a course';

  @override
  String get courseCodeLabel => 'Course code';

  @override
  String get courseCodeHint => 'Ex: X9J2P1';

  @override
  String get joinSuccess => 'You have successfully joined the course';

  @override
  String joinError(String error) {
    return 'Error: Verify the code ($error)';
  }

  @override
  String get createCourseTitle => 'Create new course';

  @override
  String get courseNameLabel => 'Course name';

  @override
  String get courseDescLabel => 'Description';

  @override
  String get studentsCedulaLabel => 'Students (IDs)';

  @override
  String get studentsCedulaHint => 'Ex: 1234567, 9876543...';

  @override
  String get createSuccess => 'Course created successfully';

  @override
  String get enrollStudentTitle => 'Enroll student';

  @override
  String get cedulaLabel => 'ID / Identification number';

  @override
  String get cedulaHint => 'Ex: 1234567890';

  @override
  String get enrollInfo =>
      'The student must be registered in SIERCP with that ID.';

  @override
  String get enrollBtn => 'Enroll';

  @override
  String get enrollSuccess => 'Student enrolled successfully';

  @override
  String get cprCertificate => 'SIERCP Certificate';

  @override
  String get courseDetail => 'Detail';

  @override
  String get courseEnroll => 'Enroll';

  @override
  String get courseExport => 'Export';

  @override
  String get courseLive => 'Live';

  @override
  String get exportGradesSuccess => 'Grades CSV exported';

  @override
  String exportGradesError(String error) {
    return 'Error exporting: $error';
  }

  @override
  String get courseStudentsTitle => 'Course students';

  @override
  String get noStudentsInscribed => 'No students enrolled';

  @override
  String get cancelBtn => 'Cancel';

  @override
  String get unirseBtn => 'Join';

  @override
  String get coursesSubtitleManage => 'CPR training management';

  @override
  String get coursesSubtitleStudent => 'Your training courses';

  @override
  String get activeCourses => 'Active courses';

  @override
  String get myCourses => 'My courses';

  @override
  String loadCoursesError(String error) {
    return 'Error loading courses: $error';
  }

  @override
  String get createBtn => 'Create';

  @override
  String studentsCount(int count) {
    return '$count students';
  }

  @override
  String get noCourseAssigned => 'No course assigned';

  @override
  String get noCourseAssignedDesc =>
      'Your instructor hasn\'t enrolled you in any course yet. Contact your instructor to join a CPR training program.';

  @override
  String get viewAvailableCourses => 'View available courses';

  @override
  String get deviceConnected => 'Device connected';

  @override
  String get deviceDisconnected => 'No device';

  @override
  String get startCPRTitle => 'Start CPR Session';

  @override
  String get startCPRDescConnected => 'Select a scenario to start';

  @override
  String get startCPRDescDisconnected =>
      'Connect the ESP32 manikin before starting';

  @override
  String get startTrainingBtn => 'Start training';

  @override
  String completedPct(String pct) {
    return '$pct% completed';
  }

  @override
  String deadlineStr(int day, int month) {
    return 'Due: $month/$day';
  }

  @override
  String get historyLoadError => 'Error loading history';

  @override
  String get historyTitle => 'History';

  @override
  String get historySubtitle => 'All your CPR sessions';

  @override
  String exportError(String error) {
    return 'Export error: $error';
  }

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get exportPdf => 'Export PDF (latest session)';

  @override
  String get exportBtn => 'Export';

  @override
  String get globalAvg => 'Global average';

  @override
  String get bestSession => 'Best session';

  @override
  String sessionsCountLabel(int count) {
    return '$count sessions';
  }

  @override
  String get studentNameFallback => 'Student';

  @override
  String get withMetrics => 'With metrics';

  @override
  String get scoreProgression => 'Score progression';

  @override
  String get latestSessions => 'Latest sessions';

  @override
  String get noSessions => 'No registered sessions.';

  @override
  String get cprSession => 'CPR Session';

  @override
  String get compLabel => 'comp.';

  @override
  String get approved => 'approved';

  @override
  String get review => 'review';

  @override
  String get noData => 'no data';

  @override
  String get selectScenarioTitle => 'Select Scenario';

  @override
  String get selectScenarioSubtitle => 'Choose the clinical case to simulate';

  @override
  String get manikinBtn => 'Manikin';

  @override
  String get scenarioInfoBanner =>
      'Select a scenario and connect the ESP32 manikin to start.';

  @override
  String get lockedScenarioMsg => 'Complete the previous modules to unlock.';

  @override
  String get newBadge => 'New';

  @override
  String get demoTitle1 => '🏠 Cardiac arrest at home';

  @override
  String get demoSub1 => 'Adult · 52 years · Sudden collapse';

  @override
  String get demoDesc1 =>
      'Family member finds the victim unconscious on the floor. No pulse or breathing.';

  @override
  String get demoTitle2 => '🚗 Traffic accident';

  @override
  String get demoSub2 => 'Adult · 35 years · Multiple traumas';

  @override
  String get demoDesc2 =>
      'Victim found on the road, unresponsive. Evaluate the scene before acting.';

  @override
  String get demoTitle3 => '🌊 Drowning in pool';

  @override
  String get demoSub3 => 'Adult · No breathing or pulse';

  @override
  String get demoDesc3 =>
      'Rescued from the pool. Drowning protocol: rescue breaths first.';

  @override
  String get demoTitle4 => '🏋️ Collapse during exercise';

  @override
  String get demoSub4 => 'Adult · 28 years · Athlete';

  @override
  String get demoDesc4 =>
      'Sudden collapse in the gym. Possible ventricular fibrillation. Use the AED.';

  @override
  String get demoTitle5 => '🍽️ Severe choking';

  @override
  String get demoSub5 => 'Adult · Airway obstruction';

  @override
  String get demoDesc5 =>
      'Family dinner. Heimlich maneuver + CPR if consciousness is lost.';

  @override
  String get demoTitle6 => '⚡ Electrical shock';

  @override
  String get demoSub6 => 'Adult · Workplace accident';

  @override
  String get demoDesc6 =>
      'Electrocuted worker. Secure the scene before touching the victim.';

  @override
  String get demoTitle7 => '🛏️ Opioid overdose';

  @override
  String get demoSub7 => 'Adult · Intoxication · Slow breathing';

  @override
  String get demoDesc7 =>
      'Overdose victim: Naloxone if available + CPR if cardiac arrest occurs.';

  @override
  String get demoTitle8 => '🚨 Heart attack evolving to arrest';

  @override
  String get demoSub8 => 'Adult · 60 years · Chest pain';

  @override
  String get demoDesc8 =>
      'Patient with chest pain that evolves into cardiac arrest. Act fast.';
}
