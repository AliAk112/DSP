import 'package:flutter/material.dart';
import 'profile.dart';
import 'movie_service.dart';
import 'movie_genres.dart';
import 'database.dart';
import 'login.dart';

class HomePage extends StatefulWidget {
  final String userEmail;
  const HomePage({super.key, required this.userEmail});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MovieService movieService = MovieService();
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<dynamic> trendingMovies = [];
  List<dynamic> genres = [];
  List<dynamic> recommendedMovies = []; // Store recommended movies
  List<dynamic> searchResults = [];
  bool isLoading = true;
  bool isSearching = false;
  TextEditingController movieSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchData();
    movieSearchController.addListener(_searchMovies);
  }

  Future<void> fetchData() async {
    try {
      final movies = await movieService.fetchTrendingMovies();
      final movieGenres = await movieService.fetchGenres();
      final recommendedTitles = await dbHelper.getRecommendedMoviesHybrid(widget.userEmail); // Get recommended movie titles

      // Fetch complete movie details for each recommended title
      List<dynamic> recommendedDetails = [];
      for (String title in recommendedTitles) {
        final movieDetails = await movieService.fetchMoviesByTitles([title]);
        if (movieDetails.isNotEmpty) {
          recommendedDetails.add(movieDetails[0]);  // Assuming fetchMoviesByTitles returns a list
        }
      }
      
      // Limit to top 20 recommendations
      final topRecommendedMovies = recommendedDetails.take(20).toList();

      setState(() {
        trendingMovies = movies;
        genres = movieGenres;
        recommendedMovies = topRecommendedMovies; // Set the top 20 recommended movies
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  Future<void> _searchMovies() async {
    if (movieSearchController.text.isEmpty) {
      setState(() {
        searchResults.clear();
        isSearching = false;
      });
    } else {
      setState(() {
        isSearching = true;
      });
      final results = await movieService.fetchMoviesByTitles([movieSearchController.text]);
      setState(() {
        searchResults = results;
      });
    }
  }

  Future<void> addToFavorites(dynamic movie) async {
    await dbHelper.addFavoriteMovie(widget.userEmail, movie['title']);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${movie['title']} added to favorites!')),
    );
  }

  void showPosterDialog(dynamic movie) {
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
                    movie['poster_path'] != null
                        ? 'https://image.tmdb.org/t/p/w500${movie['poster_path']}'
                        : 'https://via.placeholder.com/200x300?text=No+Image', // Placeholder
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
        title: Text('Movie Recommendations'),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(widget.userEmail),
              accountEmail: Text('Welcome to the Movie App!'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.redAccent),
              ),
            ),
            ListTile(
              title: Text('Profile'),
              leading: Icon(Icons.person),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(userEmail: widget.userEmail),
                  ),
                );
              },
            ),
            ListTile(
              title: Text('Logout'),
              leading: Icon(Icons.exit_to_app),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar for Movies
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: movieSearchController,
                      decoration: InputDecoration(
                        labelText: 'Search for movies',
                        border: OutlineInputBorder(),
                        suffixIcon: isSearching
                            ? CircularProgressIndicator()
                            : Icon(Icons.search),
                      ),
                    ),
                  ),
                  // Display search results as the user types
                  if (isSearching && searchResults.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: searchResults.map((movie) {
                          return ListTile(
                            leading: Image.network(
                                movie['poster_path'] != null
                                    ? 'https://image.tmdb.org/t/p/w500${movie['poster_path']}'
                                    : 'https://via.placeholder.com/50x75?text=No+Image'), // Fallback image
                            title: Text(movie['title']),
                            onTap: () => showPosterDialog(movie),
                          );
                        }).toList(),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Trending Movies',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Trending Movies Section
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: trendingMovies.length,
                      itemBuilder: (context, index) {
                        final movie = trendingMovies[index];
                        final posterUrl = movie['poster_path'] != null
                            ? 'https://image.tmdb.org/t/p/w500${movie['poster_path']}'
                            : 'https://via.placeholder.com/150x225?text=No+Image'; // Fallback image
                        return GestureDetector(
                          onTap: () => showPosterDialog(movie),
                          child: Container(
                            width: 150,
                            margin: EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: NetworkImage(posterUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                color: Colors.black.withOpacity(0.5),
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  movie['title'],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
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
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Recommended Movies',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: recommendedMovies.length,
                      itemBuilder: (context, index) {
                        final movie = recommendedMovies[index];
                        final posterUrl = movie['poster_path'] != null
                            ? 'https://image.tmdb.org/t/p/w500${movie['poster_path']}'
                            : 'https://via.placeholder.com/150x225?text=No+Image'; // Fallback image

                        return GestureDetector(
                          onTap: () => showPosterDialog(movie),
                          child: Container(
                            width: 150,
                            margin: EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: NetworkImage(posterUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                color: Colors.black.withOpacity(0.5),
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  movie['title'],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
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
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Genres',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: genres.length,
                      itemBuilder: (context, index) {
                        final genre = genres[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GenreMoviesPage(
                                  genreName: genre['name'],
                                  genreId: genre['id'],
                                  userEmail: widget.userEmail,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 8),
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                genre['name'],
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
