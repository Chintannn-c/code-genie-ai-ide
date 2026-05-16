/// API configuration for connecting to the FastAPI backend.
class ApiConfig {
  // Toggle this to true ONLY for local dev debugging
  static const bool useNgrok = false;
  static const String railwayUrl = 'https://code-genie.up.railway.app';
  static const String localUrl = 'http://192.168.1.7:8000';

  // Allow overriding the base URL via --dart-define=BASE_URL=https://your-api.com
  static String get baseUrl {
    const envUrl = String.fromEnvironment('BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    
    // Default to production Railway URL if not provided via environment
    return useNgrok ? localUrl : 'https://code-genie.up.railway.app';
  }

  static String get wsBaseUrl {
    return baseUrl.replaceAll('http://', 'ws://').replaceAll('https://', 'wss://');
  }

  // Endpoints
  static const String generate = '/api/generate';
  static const String debug = '/api/debug';
  static const String explain = '/api/explain';
  static const String stream = '/api/stream';
  static const String orchestrate = '/api/orchestrate';
  static const String health = '/api/health';
  static const String execute = '/api/execute';
  
  // File Upload & Analysis
  static const String upload = '/api/upload';
  static const String analyzeFile = '/api/analyze-file';
  static const String debugFile = '/api/debug-file';
  static const String streamAnalyzeFile = '/api/stream-analyze-file';
  static const String streamDebugFile = '/api/stream-debug-file';
  static const String patch = '/api/generate-patch';
  
  // Auth Endpoints (JWT)
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String googleLogin = '/api/auth/google';
  static const String forgotPassword = '/api/auth/forgot-password';

  // WebSocket Endpoints
  static String wsNotifications(String userId) => '/ws/$userId';

  // Dynamic Routes
  static String chats(String userId) => '/api/chats/$userId';
  static String userFiles(String userId) => '/api/user-files/$userId';
  static String messages(String chatId) => '/api/chats/$chatId/messages';
  static String chat(String chatId) => '/api/chats/$chatId';
  static String deleteChat(String chatId) => '/api/chats/$chatId';
  static String file(String fileId) => '/api/file/$fileId';
}
