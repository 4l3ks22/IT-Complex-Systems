-- 1-D.1 User management functions

-- Create user
CREATE OR REPLACE FUNCTION create_user(p_username VARCHAR, p_email VARCHAR, p_password_hash TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO users (username, email, password_hash)
    VALUES (p_username, p_email, p_password_hash);
    RETURN TRUE;
EXCEPTION
    WHEN unique_violation THEN RAISE NOTICE 'Username or email already exists'; 
		RETURN FALSE;
    WHEN OTHERS THEN RETURN FALSE;
END;
$$;

-- Read user
CREATE OR REPLACE FUNCTION read_user(p_username VARCHAR)
RETURNS TABLE(user_id INT, username VARCHAR, email VARCHAR, password_hash TEXT, creation_time TIMESTAMP)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT u.user_id, u.username, u.email, u.password_hash, u.creation_time
    FROM users u
    WHERE u.username = p_username;
END;
$$;

-- Update user with unique violation handling
CREATE OR REPLACE FUNCTION update_user(
    p_user_id INT,
    p_username VARCHAR DEFAULT NULL,
    p_email VARCHAR DEFAULT NULL,
    p_password_hash TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
DECLARE
    any_changed BOOLEAN := FALSE;
BEGIN
    -- Update username
    IF p_username IS NOT NULL THEN
        BEGIN
            UPDATE users
            SET username = p_username
            WHERE user_id = p_user_id;
            any_changed := any_changed OR FOUND;
        EXCEPTION
            WHEN unique_violation THEN
                RETURN FALSE;
        END;
    END IF;

    -- Update email
    IF p_email IS NOT NULL THEN
        BEGIN
            UPDATE users
            SET email = p_email
            WHERE user_id = p_user_id;
            any_changed := any_changed OR FOUND;
        EXCEPTION
            WHEN unique_violation THEN
                RETURN FALSE;
        END;
    END IF;

    -- Update password
    IF p_password_hash IS NOT NULL THEN
        UPDATE users
        SET password_hash = p_password_hash
        WHERE user_id = p_user_id;
        any_changed := any_changed OR FOUND;
    END IF;

    RETURN any_changed;
END;
$$;

-- Delete user
CREATE OR REPLACE FUNCTION delete_user(p_user_id INT)
RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM users WHERE user_id = p_user_id;
    RETURN FOUND;
END;
$$;

-- Create bookmark
CREATE OR REPLACE FUNCTION create_bookmark(
    p_user_id INT,
    p_title_id VARCHAR DEFAULT NULL,
    p_name_id VARCHAR DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_bookmarks(user_id, tconst, nconst)
    VALUES (p_user_id, p_title_id, p_name_id);
    RETURN TRUE;
EXCEPTION
    WHEN unique_violation THEN RETURN FALSE;
    WHEN OTHERS THEN RETURN FALSE;
END;
$$;

-- Read bookmarks
CREATE OR REPLACE FUNCTION read_bookmarks(p_user_id INT)
RETURNS TABLE(bookmark_id INT, user_id INT, tconst VARCHAR, nconst VARCHAR, bookmark_time TIMESTAMP)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT bookmark_id, user_id, tconst, nconst, bookmark_time
    FROM user_bookmarks
    WHERE user_id = p_user_id;
END;
$$;

-- Update bookmark
CREATE OR REPLACE FUNCTION update_bookmark(
    p_bookmark_id INT,
    p_title_id VARCHAR DEFAULT NULL,
    p_name_id VARCHAR DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
DECLARE
    any_changed BOOLEAN := FALSE;
BEGIN
    IF p_title_id IS NOT NULL THEN
        UPDATE user_bookmarks SET tconst = p_title_id WHERE bookmark_id = p_bookmark_id;
        any_changed := any_changed OR FOUND;
    END IF;
    IF p_name_id IS NOT NULL THEN
        UPDATE user_bookmarks SET nconst = p_name_id WHERE bookmark_id = p_bookmark_id;
        any_changed := any_changed OR FOUND;
    END IF;
    RETURN any_changed;
END;
$$;

-- Delete bookmark
CREATE OR REPLACE FUNCTION delete_bookmark(p_bookmark_id INT)
RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM user_bookmarks WHERE bookmark_id = p_bookmark_id;
    RETURN FOUND;
END;
$$;



-- 1-D.2 Simple search
CREATE OR REPLACE FUNCTION simple_search(p_query TEXT)
RETURNS TABLE(tconst VARCHAR, title TEXT)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT tconst, primarytitle
    FROM titles
    WHERE lower(primarytitle) LIKE lower('%' || p_query || '%')
    ORDER BY primarytitle
    LIMIT 100;
END;
$$;


-- 1-D.3 Title rating
CREATE OR REPLACE FUNCTION rate(
    p_user_id INT,
    p_tconst VARCHAR,
    p_rating INT
)
RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    v_prev INT;
    v_avg NUMERIC;
    v_votes INT;
BEGIN
    IF p_rating < 1 OR p_rating > 10 THEN
        RAISE EXCEPTION 'Rating must be between 1 and 10';
    END IF;

    SELECT rating INTO v_prev
    FROM user_rating_history
    WHERE user_id = p_user_id AND tconst = p_tconst
    ORDER BY rating_time DESC
    LIMIT 1;

    -- initialize ratings row if not exists
    INSERT INTO ratings(tconst, averagerating, numvotes)
    VALUES (p_tconst, NULL, 0)
    ON CONFLICT (tconst) DO NOTHING;

    SELECT averagerating, numvotes INTO v_avg, v_votes
    FROM ratings
    WHERE tconst = p_tconst;

    IF v_avg IS NULL THEN v_avg := 0; END IF;
    IF v_votes IS NULL THEN v_votes := 0; END IF;

    IF v_prev IS NULL THEN
        v_avg := ((v_avg * v_votes) + p_rating)::numeric / NULLIF(v_votes + 1, 0);
        v_votes := v_votes + 1;
    ELSE
        v_avg := ((v_avg * v_votes) - v_prev + p_rating)::numeric / NULLIF(v_votes, 0);
    END IF;

    UPDATE ratings SET averagerating = v_avg, numvotes = v_votes WHERE tconst = p_tconst;

    IF v_prev IS NULL THEN
        INSERT INTO user_rating_history(user_id, tconst, rating)
        VALUES (p_user_id, p_tconst, p_rating);
    ELSE
        UPDATE user_rating_history
        SET rating = p_rating, rating_time = NOW()
        WHERE user_id = p_user_id AND tconst = p_tconst;
    END IF;
END;
$$;



-- 1-D.4 Structured search
CREATE OR REPLACE FUNCTION structured_string_search(
    p_user_id INT,
    p_title TEXT,
    p_plot TEXT,
    p_characters TEXT,
    p_person_name TEXT
)
RETURNS TABLE(tconst VARCHAR, title TEXT)
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM log_search(p_user_id, concat_ws(' | ', p_title, p_plot, p_characters, p_person_name));

    RETURN QUERY
    WITH candidate_titles AS (
        SELECT t.tconst, t.primarytitle AS title
        FROM titles t
        LEFT JOIN title_extras te ON te.tconst = t.tconst
        WHERE (p_title IS NULL OR lower(t.primarytitle) LIKE lower('%' || p_title || '%'))
          AND (p_plot IS NULL OR (te.plot IS NOT NULL AND lower(te.plot) LIKE lower('%' || p_plot || '%')))
    ),
    char_filtered AS (
        SELECT DISTINCT ct.tconst, ct.title
        FROM candidate_titles ct
        LEFT JOIN participates_in_title pit ON pit.tconst = ct.tconst
        WHERE p_characters IS NULL
           OR (pit.characters IS NOT NULL AND lower(regexp_replace(pit.characters, '[\[\]"]', '', 'g')) LIKE lower('%' || p_characters || '%'))
    ),
    person_filtered AS (
        SELECT DISTINCT cf.tconst, cf.title
        FROM char_filtered cf
        LEFT JOIN participates_in_title pit2 ON pit2.tconst = cf.tconst
        LEFT JOIN persons n ON n.nconst = pit2.nconst
        WHERE p_person_name IS NULL
           OR (n.primaryname IS NOT NULL AND lower(n.primaryname) LIKE lower('%' || p_person_name || '%'))
    )
    SELECT tconst, title
    FROM person_filtered
    ORDER BY title
    LIMIT 500;
END;
$$;


-- 1_D.5 Finding Names
CREATE OR REPLACE FUNCTION name_search(p_user_id INT, p_query TEXT)
RETURNS TABLE(nconst VARCHAR, primaryname TEXT)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_user_id IS NOT NULL THEN
        INSERT INTO user_search_history(user_id, search_term, search_time)
        VALUES (p_user_id, p_query, NOW());
    END IF;

    RETURN QUERY
    SELECT n.nconst, n.primaryname
    FROM persons n
    WHERE lower(n.primaryname) LIKE lower('%' || p_query || '%')
    ORDER BY n.primaryname
    LIMIT 100;
END;
$$;

-- 1_D.6 Finding co-players
CREATE OR REPLACE FUNCTION co_players(p_name TEXT)
RETURNS TABLE(nconst VARCHAR, primaryname TEXT, frequency INT)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  WITH target AS (
    SELECT DISTINCT pit.tconst
    FROM persons n
    JOIN participates_in_title pit ON pit.nconst = n.nconst
    WHERE lower(n.primaryname) LIKE lower('%' || p_name || '%')
  )
  SELECT n2.nconst, n2.primaryname, COUNT(*) AS frequency
  FROM target t
  JOIN participates_in_title pit2 ON pit2.tconst = t.tconst
  JOIN persons n2 ON n2.nconst = pit2.nconst
  WHERE lower(n2.primaryname) <> lower(p_name)
  GROUP BY n2.nconst, n2.primaryname
  ORDER BY frequency DESC, n2.primaryname
  LIMIT 20;
END;
$$;

-- 1_D.7 Name rating
CREATE OR REPLACE FUNCTION update_name_rating(p_nconst VARCHAR)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO name_ratings(nconst, weighted_rating)
  SELECT pit.nconst,
         SUM(r.averagerating * r.numvotes)::NUMERIC / NULLIF(SUM(r.numvotes),0)
  FROM participates_in_title pit
  JOIN ratings r ON r.tconst = pit.tconst
  WHERE pit.nconst = p_nconst
  GROUP BY pit.nconst
  ON CONFLICT (nconst) DO UPDATE
  SET weighted_rating = EXCLUDED.weighted_rating;
END;
$$;

-- 1_D.8 Popular actors
CREATE OR REPLACE FUNCTION popular_actors(p_tconst VARCHAR)
RETURNS TABLE(nconst VARCHAR, primaryname TEXT, popularity NUMERIC)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT per.nconst, per.primaryname, nr.weighted_rating AS popularity
  FROM participates_in_title pit
  JOIN persons per ON per.nconst = pit.nconst
  LEFT JOIN name_ratings nr ON nr.nconst = per.nconst
  WHERE pit.tconst = p_tconst
  ORDER BY nr.weighted_rating DESC NULLS LAST, per.primaryname;
END;
$$;


-- 1_D.9 Similar movies
CREATE OR REPLACE FUNCTION similar_movies(p_tconst VARCHAR)
RETURNS TABLE(tconst VARCHAR, title TEXT, similarity INT)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  WITH movie_genres AS (
    SELECT DISTINCT genre
    FROM title_genre
    WHERE tconst = p_tconst
  )
  SELECT t.tconst, t.primarytitle, COUNT(DISTINCT tg.genre) AS similarity
  FROM titles t
  JOIN title_genre tg ON tg.tconst = t.tconst
  JOIN movie_genres mg ON mg.genre = tg.genre
  WHERE t.tconst <> p_tconst
  GROUP BY t.tconst, t.primarytitle
  HAVING COUNT(DISTINCT tg.genre) > 0
  ORDER BY similarity DESC, t.primarytitle
  LIMIT 20;
END;
$$;

-- 1_D.10 Frequent person words
CREATE OR REPLACE FUNCTION person_words(p_name TEXT, p_limit INT DEFAULT 10)
RETURNS TABLE(word TEXT, frequency INT)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  WITH target_person AS (
    SELECT nconst
    FROM persons
    WHERE lower(primaryname) LIKE lower('%' || p_name || '%')
  ),
  related_titles AS (
    SELECT DISTINCT pit.tconst
    FROM participates_in_title pit
    JOIN target_person tp ON tp.nconst = pit.nconst
  ),
  words AS (
    SELECT wi.word
    FROM word_index wi
    JOIN related_titles rt ON rt.tconst = wi.tconst
  )
  SELECT w.word, COUNT(*) AS frequency
  FROM words w
  GROUP BY w.word
  ORDER BY frequency DESC, w.word
  LIMIT p_limit;
END;
$$;


-- 1_D.11 Exact-match querying
CREATE OR REPLACE FUNCTION query_match(p_keywords TEXT[])
RETURNS TABLE(tconst VARCHAR, title TEXT)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT t.tconst, t.primarytitle
  FROM word_index wi
  JOIN titles t ON t.tconst = wi.tconst
  WHERE wi.word = ANY(p_keywords)
  GROUP BY t.tconst, t.primarytitle
  HAVING COUNT(DISTINCT wi.word) = array_length(p_keywords, 1)
  ORDER BY t.primarytitle
  LIMIT 100;
END;
$$;


-- 1_D.12 Best-match querying
CREATE OR REPLACE FUNCTION query_best_match(p_keywords TEXT[], p_limit INT DEFAULT 100)
RETURNS TABLE(tconst VARCHAR, title TEXT, rank INT)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT t.tconst, t.primarytitle, COUNT(DISTINCT wi.word) AS rank
  FROM word_index wi
  JOIN titles t ON t.tconst = wi.tconst
  WHERE wi.word = ANY(p_keywords)
  GROUP BY t.tconst, t.primarytitle
  ORDER BY rank DESC, t.primarytitle
  LIMIT p_limit;
END;
$$;


-- 1_D.13 Word-to-words querying
CREATE OR REPLACE FUNCTION query_word_to_words(
    p_keywords TEXT[],
    p_limit INT DEFAULT 20
)
RETURNS TABLE(word TEXT, frequency INT)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  WITH matched_titles AS (
    SELECT DISTINCT wi.tconst
    FROM word_index wi
    WHERE wi.word = ANY(p_keywords)
  ),
  collected_words AS (
    SELECT wi.word
    FROM word_index wi
    JOIN matched_titles mt ON mt.tconst = wi.tconst
    WHERE wi.word <> ALL(p_keywords) -- exclude the query words themselves
  )
  SELECT word, COUNT(*) AS frequency
  FROM collected_words
  GROUP BY word
  ORDER BY frequency DESC, word
  LIMIT p_limit;
END;
$$;