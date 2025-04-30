import 'package:flutter/material.dart';
import 'movie_service.dart';
import 'database.dart';
import 'profile.dart';

class GenreMoviesPage extends StatefulWidget {
  final String genreName;
  final int genreId;
  final String userEmail;

  const GenreMoviesPage({required this.genreName, required this.genreId, required this.userEmail});

  @override
  _GenreMoviesPageState createState() => _GenreMoviesPageState();
}

class _GenreMoviesPageState extends State<GenreMoviesPage> {
  final MovieService movieService = MovieService();
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<dynamic> movies = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMovies();
  }

  Future<void> fetchMovies() async {
    try {
      final genreMovies = await movieService.fetchMoviesByGenre(widget.genreId);
      setState(() {
        movies = genreMovies;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching movies by genre: $e');
    }
  }

  Future<void> addToFavorites(dynamic movie) async {
    try {
      // Assuming you have a way to get the current user's email
      await dbHelper.addFavoriteMovie(widget.userEmail, movie['title']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${movie['title']} added to favorites!')),
      );
    } catch (e) {
      print('Error adding favorite: $e');
    }
  }

  Future<void> addGenreToFavorites() async {
    try {
      // Save the genre to the user's favorites in the database
      await dbHelper.addFavoriteGenre(widget.userEmail, widget.genreName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.genreName} added to favorite genres!')),
      );
    } catch (e) {
      print('Error adding genre to favorites: $e');
    }
  }

  void showMovieDetailsDialog(dynamic movie) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: EdgeInsets.all(16),
            height: 700,
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Image.network(
                    'https://image.tmdb.org/t/p/w500${movie['poster_path']}',
                    height: 300,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  movie['title'],
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      movie['overview'] ?? 'No description available.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Close'),
                    ),
                    IconButton(
                      icon: Icon(Icons.favorite, color: Colors.redAccent),
                      onPressed: () => addToFavorites(movie),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.genreName),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(userEmail: widget.userEmail),
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // GridView for displaying movies
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: movies.length,
                    itemBuilder: (context, index) {
                      final movie = movies[index];
                      return GestureDetector(
                        onTap: () => showMovieDetailsDialog(movie),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(
                                'https://image.tmdb.org/t/p/w500${movie['poster_path']}',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              color: Colors.black.withOpacity(0.7),
                              padding: EdgeInsets.all(8),
                              child: Text(
                                movie['title'],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Button to add the genre to favorite genres
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: addGenreToFavorites,
                    child: Text('Add Genre to Favorites'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
