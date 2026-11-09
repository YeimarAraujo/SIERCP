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
  String get forgotPassSuccess => 'Reset email sent.';

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
  String get privacyPolicyTitle => 'Privacy Policy';

  @override
  String get privacyPolicyContent =>
      '1. Introduction\n\nThe CPR Training System is committed to protecting the privacy and security of its users\' personal information. This policy explains how we collect, use, store, and protect personal data in accordance with current Colombian regulations (Law 1581 of 2012 and complementary standards).\n\n2. Information We Collect\n\nWe may collect the following information:\n\nPersonal data: full name, identification number, email, phone number.\nAcademic or professional data: institution, position, previous certifications.\nSystem usage data: module progress, evaluation results, access dates.\nTechnical information: IP address, device type, and browser.\n\n3. Purpose of Data Processing\n\nThe collected information will be used to:\n\nManage system registration and access.\nMonitor user progress in CPR modules.\nIssue participation or approval certificates.\nSend relevant information about training or updates.\nImprove service quality and user experience.\n\n4. Storage and Security\n\nInformation will be stored in secure databases, and technical, administrative, and organizational measures will be implemented to prevent unauthorized access, loss, or alteration of information.\n\n5. Sharing Information\n\nPersonal data will not be sold or shared with third parties, except:\n\nWhen required by a competent authority.\nWhen necessary to issue official certifications.\nWhen the user provides express authorization.\n\n6. User Rights\n\nIn accordance with Colombian legislation, users have the right to:\n\nKnow, update, and rectify their personal data.\nRequest proof of the authorization granted.\nRevoke authorization or request the deletion of their data.\nFile complaints with the Superintendency of Industry and Commerce.\n\n7. Use of Cookies\n\nThe system may use cookies to improve the browsing experience and analyze platform usage.\n\n8. Policy Modifications\n\nWe reserve the right to update this policy at any time. Changes will be published on the platform.\n\n9. Contact\n\nFor inquiries related to privacy and data processing, you can communicate through the official system email.';

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
      'Manikin not detected. Check Simulator connection.';

  @override
  String get adminDashboardTitle => 'Control Panel';

  @override
  String get adminLoginWebOnly =>
      'Administrators must log in from the web version.';

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
  String get joinErrorInvalidCode => 'Error: Verify the code';

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

  @override
  String get scanQr => 'Scan QR';

  @override
  String get qrHint => 'Type the code or tap the QR icon to scan.';

  @override
  String get qrSuccess => 'QR scanned successfully';

  @override
  String get scanAgain => 'Scan again';

  @override
  String get aimQrHint => 'Point at the course QR code';

  @override
  String get qrScannerTitle => 'Scan QR Code';

  @override
  String get cameraPermissionRequired => 'Camera permission required';

  @override
  String get grantPermission => 'Grant permission';

  @override
  String get createCourseBtn => 'Create';

  @override
  String get courseCreatedSuccess => 'Course created successfully';

  @override
  String get deleteCourseConfirmTitle => 'Delete course?';

  @override
  String deleteCourseConfirmDesc(String title) {
    return 'This action will deactivate the course \"$title\". Students will no longer be able to access it.';
  }

  @override
  String get deleteBtn => 'Delete';

  @override
  String get editCourseTitle => 'Edit course';

  @override
  String get saveBtn => 'Save';

  @override
  String get modulesBtn => 'Modules';

  @override
  String get studentsBtn => 'Students';

  @override
  String get qrBtn => 'QR';

  @override
  String get completed => 'Completed';

  @override
  String remainingSessions(int count) {
    return '$count sessions remaining';
  }

  @override
  String shareInviteText(String title, String code) {
    return 'Join my CPR course at SIERCP!\nCourse: $title\nInvitation code: $code\n\nOr scan the QR from the app.';
  }

  @override
  String get shareInviteSubject => 'SIERCP Course Invitation';

  @override
  String get shareInviteBtn => 'Share invitation';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get ahaTipTitle => 'AHA 2025 Tip';

  @override
  String get ahaTipBody =>
      'Remember that compression depth should be at least 5 cm (2 inches) but no more than 6 cm (2.4 inches). Allow full chest recoil after each compression.';

  @override
  String get totalStudents => 'Students';

  @override
  String get activeManikins => 'Manikins';

  @override
  String get alertsToday => 'Alerts Today';

  @override
  String get manageUsers => 'Users';

  @override
  String get manageManikins => 'Manikins';

  @override
  String get manageCourses => 'Courses';

  @override
  String get manageReports => 'Reports';

  @override
  String get manageAnalytics => 'Analytics';

  @override
  String get quickNewCourse => 'New Course';

  @override
  String get quickMyStudents => 'My Students';

  @override
  String get quickExport => 'Export';

  @override
  String get activeCoursesTitle => 'My active courses';

  @override
  String get navReports => 'Reports';

  @override
  String get navAnalytics => 'Analytics';

  @override
  String get equipmentSectionTitle => 'Equipment & Connectivity';

  @override
  String get manikinsLabel => 'SIERCP Manikins';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get errorOpeningLink => 'Could not open the link';

  @override
  String devicesConnectedCount(int count) {
    return '$count connected';
  }

  @override
  String get noInternet => 'NO INTERNET CONNECTION';

  @override
  String get continueLearning => 'Continue Learning';

  @override
  String get viewDetail => 'View Detail';

  @override
  String get continueTraining => 'Continue Training';

  @override
  String get connected => 'Connected';

  @override
  String get noDeviceMini => 'No disp.';

  @override
  String approvedAndSessions(
      int approvedCount, int requiredCount, int totalDone) {
    return '$approvedCount/$requiredCount approved · $totalDone sessions';
  }

  @override
  String get navSimulation => 'Practice';

  @override
  String get simulationTitle => 'Practice';

  @override
  String get simulationSubtitle => 'Theoretical and practical evaluations';

  @override
  String get theoreticalEval => 'Theoretical Evaluation';

  @override
  String get theoreticalEvalDesc =>
      'Answer dynamic questions based on AHA and MinSalud guidelines';

  @override
  String get practicalEval => 'Practical Evaluation';

  @override
  String get practicalEvalDesc => 'Practice with the ESP32 manikin connected';

  @override
  String get quizTopicsTitle => 'Select a topic';

  @override
  String get quizTopicsSubtitle =>
      'Evaluations based on AHA and MinSalud guidelines';

  @override
  String get quizStart => 'Start evaluation';

  @override
  String quizQuestionLabel(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String get quizTimeLeft => 'Time remaining';

  @override
  String get quizSubmit => 'Finish evaluation';

  @override
  String get quizResultTitle => 'Result';

  @override
  String get quizPassed => 'Passed!';

  @override
  String get quizFailed => 'Not passed';

  @override
  String quizScore(String score) {
    return '$score%';
  }

  @override
  String quizXpEarned(int xp) {
    return '+$xp XP earned';
  }

  @override
  String quizCorrectOf(int correct, int total) {
    return '$correct of $total correct';
  }

  @override
  String get quizRetry => 'Try again';

  @override
  String get quizReviewAnswers => 'Review answers';

  @override
  String quizLevelUp(int level) {
    return 'Level up! You reached level $level!';
  }

  @override
  String get quizNewBadge => 'Badge earned';

  @override
  String quizPlanRequired(String plan) {
    return 'Requires $plan plan';
  }

  @override
  String get quizLoading => 'Loading questions...';

  @override
  String get quizSubmitting => 'Submitting answers...';

  @override
  String get quizErrorLoad => 'Failed to load questions. Please try again.';

  @override
  String get quizErrorSubmit => 'Failed to submit answers. Please try again.';

  @override
  String get quizAnswerAll => 'Answer all questions before submitting';

  @override
  String get quizTimeUp => 'Time\'s up!';

  @override
  String get quizMinScore => 'Minimum passing score: 70%';

  @override
  String get practicalTitle => 'Practical Evaluation';

  @override
  String get practicalSubtitle => 'Choose the type of practice';

  @override
  String get practicalRcp => 'CPR with Manikin';

  @override
  String get practicalRcpDesc =>
      'Practice compressions and ventilations with real-time feedback';

  @override
  String get practicalScenarios => 'Clinical Scenarios';

  @override
  String get practicalScenariosDesc =>
      'Simulate emergency cases with the full protocol';

  @override
  String get practicalDeviceRequired => 'ESP32 manikin connection required';

  @override
  String get practicalConnectFirst => 'Connect manikin';

  @override
  String get calendarTitle => 'My Calendar';

  @override
  String get calendarSubtitle => 'Session, evaluation and certificate history';

  @override
  String get calendarInstitutionTitle => 'Institution Calendar';

  @override
  String get calendarNoEvents => 'No activity on this day';

  @override
  String get calendarEventQuiz => 'Evaluation';

  @override
  String get calendarEventSession => 'Session';

  @override
  String get calendarEventCertificate => 'Certificate';

  @override
  String get calendarLoading => 'Loading events...';

  @override
  String get calendarError => 'Failed to load calendar';

  @override
  String get calendarRetry => 'Retry';

  @override
  String get calendarBannerTitle => 'My Calendar';

  @override
  String get calendarBannerSubtitle => 'Activity and progress history';
}
