import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'movie_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._();
  static Database? _database;

  DatabaseHelper._();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'users.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE,
            password TEXT,
            username TEXT,
            favoriteGenres TEXT,
            favoriteMovies TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE users ADD COLUMN favoriteGenres TEXT;");
          await db.execute("ALTER TABLE users ADD COLUMN favoriteMovies TEXT;");
        }
        if (oldVersion < 4) {
          await db.execute("ALTER TABLE users ADD COLUMN username TEXT;");
        }
      },
    );
  }

  double JaccardSimilarity(List<String> listA, List<String> listB) {
    final setA = Set<String>.from(listA);
    final setB = Set<String>.from(listB);
    if (setA.isEmpty || setB.isEmpty) return 0.0;
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return intersection / union;
  }

  Future<int> registerUser(String email, String password, String username) async {
    final db = await database;
    return await db.insert('users', {
      'email': email,
      'password': password,
      'username': username,
      'favoriteGenres': '',
      'favoriteMovies': '',
    });
  }

  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> getUserProfile(String email) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateUserPreferences(String email, Map<String, dynamic> updatedData) async {
    final db = await database;
    return await db.update(
      'users',
      updatedData,
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  Future<int> updatePassword(String email, String newPassword) async {
    final db = await database;
    return await db.update(
      'users',
      {'password': newPassword},
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  Future<int> updateUsername(String email, String newUsername) async {
    final db = await database;
    return await db.update(
      'users',
      {'username': newUsername},
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  Future<void> addFavoriteMovie(String email, String movieTitle) async {
    final db = await database;
    final user = await getUserProfile(email);
    if (user != null) {
      String currentFavorites = user['favoriteMovies'] ?? '';
      List<String> favoritesList = currentFavorites.isNotEmpty
          ? currentFavorites.split(',')
          : [];
      if (!favoritesList.contains(movieTitle)) {
        favoritesList.add(movieTitle);
        String updatedFavorites = favoritesList.join(',');
        await db.update(
          'users',
          {'favoriteMovies': updatedFavorites},
          where: 'email = ?',
          whereArgs: [email],
        );
      }
    }
  }

  Future<void> removeFavoriteMovie(String email, String movieTitle) async {
    final db = await database;
    final user = await getUserProfile(email);
    if (user == null) return;

    String currentFavorites = user['favoriteMovies'] ?? '';
    List<String> favoritesList = currentFavorites
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    favoritesList.removeWhere((title) => title == movieTitle);

    String updatedFavorites = favoritesList.join(',');

    await db.update(
      'users',
      {'favoriteMovies': updatedFavorites},
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  Future<void> addFavoriteGenre(String email, String genreName) async {
    final db = await database;
    final user = await getUserProfile(email);
    if (user != null) {
      String currentGenres = user['favoriteGenres'] ?? '';
      List<String> genresList = currentGenres.isNotEmpty
          ? currentGenres.split(',')
          : [];
      if (!genresList.contains(genreName)) {
        genresList.add(genreName);
        String updatedGenres = genresList.join(',');
        await db.update(
          'users',
          {'favoriteGenres': updatedGenres},
          where: 'email = ?',
          whereArgs: [email],
        );
      }
    }
  }

  Future<List<String>> getFavoriteGenres(String email) async {
    final user = await getUserProfile(email);
    if (user != null && user['favoriteGenres'] != null && user['favoriteGenres'].isNotEmpty) {
      return user['favoriteGenres'].split(',');
    }
    return [];
  }

  Future<void> removeFavoriteGenre(String email, String genreName) async {
    final db = await database;
    final user = await getUserProfile(email);
    if (user == null) return;

    String currentGenres = user['favoriteGenres'] ?? '';
    List<String> genresList = currentGenres
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    genresList.removeWhere((genre) => genre == genreName);

    String updatedGenres = genresList.join(',');

    await db.update(
      'users',
      {'favoriteGenres': updatedGenres},
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  Future<List<String>> getRecommendedMoviesHybrid(String email) async {
    final db = await database;
    final currentUser = await getUserProfile(email);
    if (currentUser == null) return [];

    final movieService = MovieService();

    // Fetch user data
    List<String> currentUserFavorites = (currentUser['favoriteMovies'] as String)
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    List<String> currentUserGenres = (currentUser['favoriteGenres'] as String)
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // Initialize variables
    Map<String, int> similarMoviesCount = {};
    List<double> similarityScores = [];
    List<String> genreMatchedUsers = [];
    Set<String> allRecommendedMovies = {};

    // Fetch TMDB genre list for genre-to-ID mapping
    final genreList = await movieService.fetchGenres();
    final genreMap = {for (var g in genreList) g['name']: g['id']};

    // Collaborative Filtering Logic
    final allUsers = await db.query('users', where: 'email != ?', whereArgs: [email]);

    for (var user in allUsers) {
      List<String> otherUserFavorites = (user['favoriteMovies'] as String)
          .split(',')
          .map((e) => e.trim())
          .toList();

      List<String> otherUserGenres = (user['favoriteGenres'] as String)
          .split(',')
          .map((e) => e.trim())
          .toList();

      // Jaccard Similarity between users based on favorite movies
      double similarity = JaccardSimilarity(currentUserFavorites, otherUserFavorites);
      similarityScores.add(similarity);

      // Check for genre overlap
      final commonGenres = currentUserGenres.toSet().intersection(otherUserGenres.toSet());
      if (commonGenres.isNotEmpty) {
        for (var movie in otherUserFavorites) {
          if (!currentUserFavorites.contains(movie)) {
            similarMoviesCount[movie] = (similarMoviesCount[movie] ?? 0) + 1;
          }
        }
        genreMatchedUsers.add(user['email'] as String);
      }
    }

    // Sort recommendations by count from collaborative filtering
    List<MapEntry<String, int>> collaborativeRecs = similarMoviesCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Content-Based Filtering (Movies Based on Favorite Genres)
    Set<String> genreRecommendations = {};

    // Fetch movies for each of the user's favorite genres using TMDB API
    for (String genre in currentUserGenres) {
      if (genreMap.containsKey(genre)) {
        final genreId = genreMap[genre];
        final genreMovies = await movieService.fetchMoviesByGenre(genreId);

        for (var movie in genreMovies) {
          String title = movie['title'];
          if (!currentUserFavorites.contains(title)) {
            genreRecommendations.add(title); // Add genre-related movie recommendations
          }
        }
      }
    }

    // Combine genre recommendations with collaborative filtering
    allRecommendedMovies.addAll(genreRecommendations);

    // Adjusting Weights Based on Genre Overlap
    double collaborativeWeight = genreMatchedUsers.isNotEmpty ? 0.4 : 0.2;
    double contentBasedWeight = genreMatchedUsers.isNotEmpty ? 0.6 : 0.8;

    // Hybrid Recommendations
    int collaborativeLimit = (collaborativeRecs.length * collaborativeWeight).toInt();
    allRecommendedMovies.addAll(collaborativeRecs.take(collaborativeLimit).map((e) => e.key));

    int contentBasedLimit = (genreRecommendations.length * contentBasedWeight).toInt();
    allRecommendedMovies.addAll(genreRecommendations.take(contentBasedLimit));

    return allRecommendedMovies.toList();
  }


}