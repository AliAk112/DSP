import 'dart:convert';
import 'package:http/http.dart' as http;

class MovieService {
  final String apiKey = '2367760e851f461d5cc92e63b0426300';
  final String baseUrl = 'https://api.themoviedb.org/3';

  Future<List<dynamic>> fetchTrendingMovies() async {
    final url = Uri.parse('$baseUrl/trending/movie/week?api_key=$apiKey');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results'];
    } else {
      throw Exception('Failed to load trending movies');
    }
  }

  Future<List<dynamic>> fetchGenres() async {
    final url = Uri.parse('$baseUrl/genre/movie/list?api_key=$apiKey');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['genres'];
    } else {
      throw Exception('Failed to load genres');
    }
  }

  Future<List<dynamic>> fetchMoviesByGenre(int genreId) async {
    final url = Uri.parse('$baseUrl/discover/movie?api_key=$apiKey&with_genres=$genreId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results'];
    } else {
      throw Exception('Failed to load movies by genre');
    }
  }

  Future<List<dynamic>> fetchMoviesByTitles(List<String> titles) async {
    List<dynamic> movies = [];

    for (String title in titles) {
      final url = Uri.parse('$baseUrl/search/movie?api_key=$apiKey&query=$title');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'].isNotEmpty) {
          var movie = data['results'][0];
          if (movie['poster_path'] != null && movie['poster_path'] != '') {
            movies.add(movie); // Add only if it has a poster
          }
        }
      } else {
        throw Exception('Failed to fetch movie: $title');
      }
    }

    return movies;
  }

  Future<List<dynamic>> fetchSimilarMovies(int movieId) async {
    final url = Uri.parse('$baseUrl/movie/$movieId/similar?api_key=$apiKey');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results']
          .where((movie) => movie['poster_path'] != null && movie['poster_path'] != '')
          .toList();
    } else {
      throw Exception('Failed to fetch similar movies for ID: $movieId');
    }
  }
}
