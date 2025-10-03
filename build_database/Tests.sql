-- Create, read, update and delete user

SELECT create_user('Cesar', 'cesar@abuelo.dk', 'test');

SELECT read_user('Cesar');

SELECT update_user(1, 'Cesar', 'cesar@ruc.dk');

SELECT delete_user(1);

-- Create, read, update and delete bookmark
-- Need user to have bookmarks
SELECT create_user ('Alin', 'alin@eugen.dk', 'bookmarktest');

SELECT create_bookmark(2, 'tt0757240');

SELECT read_bookmarks(2);

SELECT update_bookmark(2, 'tt13321042');

SELECT read_bookmarks(2);

SELECT delete_bookmark(2);

SELECT read_bookmarks(2);

-- Simple Search test
SELECT simple_search(2, 'hello');
SELECT simple_search(NULL , 'matrix'); -- search without user
SELECT * from user_search_history; -- checking search history if user was registered

-- Rating test
SELECT * from ratings where tconst = 'tt32452395'; -- before rating
SELECT rate(2, 'tt32452395', 10);
SELECT * from ratings where tconst = 'tt32452395'; -- after rating

-- Structured search
SELECT structured_string_search(2, 'matrix');

-- Finding names test
SELECT name_search(2, 'alin');

-- Finding co-players test
SELECT co_players('Keanu Angelo');

-- Name rating test
SELECT update_name_rating('nm4481520');
SELECT * FROM name_ratings;

SELECT simple_search(2, 'top gun: maverick');

-- Popular actors test
SELECT popular_actors('tt1745960');

-- Similar movies
SELECT similar_movies('tt19403210');