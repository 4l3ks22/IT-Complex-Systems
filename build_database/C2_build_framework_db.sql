DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS user_search_history CASCADE;
DROP TABLE IF EXISTS user_rating_history CASCADE;
DROP TABLE IF EXISTS user_bookmarks CASCADE;

-- Create new tables for registrations, search/rating history and bookmarks for users
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(50) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    creation_time TIMESTAMP DEFAULT NOW()
);

CREATE TABLE user_search_history (
    search_id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(user_id) ON DELETE CASCADE,
    search_term TEXT NOT NULL,
    search_time TIMESTAMP DEFAULT NOW()
);

CREATE TABLE user_rating_history (
    rating_id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(user_id) ON DELETE CASCADE,
    tconst VARCHAR(20) REFERENCES titles(tconst) ON DELETE CASCADE,
    rating INT CHECK (rating BETWEEN 1 AND 10),
    rating_time TIMESTAMP DEFAULT NOW()
);

CREATE TABLE user_bookmarks (
    bookmark_id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(user_id) ON DELETE CASCADE,
    tconst VARCHAR(20) REFERENCES titles(tconst) ON DELETE CASCADE,
    nconst VARCHAR(20) REFERENCES persons(nconst) ON DELETE CASCADE,
    bookmark_time TIMESTAMP DEFAULT NOW(),
    CONSTRAINT one_of_title_or_name CHECK (
        (tconst IS NOT NULL) OR (nconst IS NOT NULL)
    )
);



