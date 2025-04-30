import 'package:flutter/material.dart';
import 'database.dart';
import 'movie_service.dart';

class ProfilePage extends StatefulWidget {
  final String userEmail;

  ProfilePage({required this.userEmail});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final MovieService movieService = MovieService();

  TextEditingController passwordController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  List<dynamic> favoriteMovies = [];
  List<String> favoriteGenres = [];
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    loadUserProfile();
  }

  Future<void> loadUserProfile() async {
    Map<String, dynamic>? user = await dbHelper.getUserProfile(widget.userEmail);
    if (user != null) {
      setState(() {
        usernameController.text = user['username'] ?? '';     // Load username
        favoriteGenres = (user['favoriteGenres'] ?? '').split(','); // Load favorite genres as a list
      });
      await loadFavoriteMovies(user['favoriteMovies'] ?? '');
    }
  }

  Future<void> loadFavoriteMovies(String movieTitles) async {
    if (movieTitles.isEmpty) return;
    List<dynamic> movies = await movieService.fetchMoviesByTitles(movieTitles.split(','));
    setState(() {
      favoriteMovies = movies;
    });
  }

  Future<void> saveProfile() async {
    await dbHelper.updateUserPreferences(widget.userEmail, {
      'username': usernameController.text,     // Save the updated username
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Profile updated successfully!')),
    );
    setState(() {
      isEditing = false;
    });
  }

  Future<void> updatePassword() async {
    if (passwordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password must be at least 8 characters long!')),
      );
      return;
    }
    await dbHelper.updatePassword(widget.userEmail, passwordController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Password updated successfully!')),
    );
    passwordController.clear();
  }

  Future<void> removeMovieFromFavorites(String movieTitle) async {
    await dbHelper.removeFavoriteMovie(widget.userEmail, movieTitle);
    await loadUserProfile();
  }

  Future<void> removeGenreFromFavorites(String genre) async {
    // Remove genre from the list
    favoriteGenres.remove(genre);

    // Update the favoriteGenres in the database
    await dbHelper.updateUserPreferences(widget.userEmail, {
      'favoriteGenres': favoriteGenres.join(','),
    });

    // Reload the profile to reflect changes
    loadUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile Settings'),
        backgroundColor: Colors.redAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Username Section
            Text('Username:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(
              controller: usernameController,
              enabled: isEditing,
              decoration: InputDecoration(hintText: 'Enter your username'),
            ),
            SizedBox(height: 10),
            
            // Favorite Genres Section
            Text('Favorite Genres:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            favoriteGenres.isEmpty
                ? Text('No favorite genres added yet.')
                : Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: favoriteGenres.map((genre) {
                      return Chip(
                        label: Text(genre),
                        deleteIcon: Icon(Icons.delete),
                        onDeleted: () async {
                          await removeGenreFromFavorites(genre);
                        },
                      );
                    }).toList(),
                  ),
            SizedBox(height: 10),
            
            // Edit Button
            isEditing
                ? ElevatedButton(
                    onPressed: saveProfile,
                    child: Text('Save Profile'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  )
                : ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isEditing = true;
                      });
                    },
                    child: Text('Edit Profile'),
                  ),
            SizedBox(height: 20),
            
            // Update Password Section
            Text('Update Password:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(hintText: 'Enter new password'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: updatePassword,
              child: Text('Update Password'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
            SizedBox(height: 20),

            // Favorite Movies Section
            Text('Favorite Movies:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            favoriteMovies.isEmpty
                ? Text('No favorite movies added yet.')
                : Container(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: favoriteMovies.length,
                      itemBuilder: (context, index) {
                        final movie = favoriteMovies[index];
                        return GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(movie['title']),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.network(
                                      'https://image.tmdb.org/t/p/w500${movie['poster_path']}',
                                      height: 200,
                                    ),
                                    SizedBox(height: 10),
                                    Text('Remove from favorites?'),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.of(context).pop();
                                      await removeMovieFromFavorites(movie['title']);
                                    },
                                    child: Text('Remove'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: Text('Cancel'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 8),
                            width: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: NetworkImage('https://image.tmdb.org/t/p/w500${movie['poster_path']}'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
