-- 1-D.1 User management functions
-- Create user 
CREATE
OR REPLACE FUNCTION create_user (input_username VARCHAR, input_email VARCHAR, input_password_hash TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO users (username, email, password_hash)
  VALUES
  (input_username, input_email, input_password_hash);
END;
$$;
-- Read user
CREATE
OR REPLACE FUNCTION read_user (input_username VARCHAR) RETURNS TABLE (user_id INT, username VARCHAR, email VARCHAR, password_hash TEXT, creation_time TIMESTAMP) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY SELECT
    users.user_id,
    users.username,
    users.email,
    users.password_hash,
    users.creation_time
  FROM
    users
  WHERE
    users.username = input_username;
END;
$$;

-- Update user 
CREATE
OR REPLACE FUNCTION update_user (input_user_id INT, input_username VARCHAR DEFAULT NULL, input_email VARCHAR DEFAULT NULL, input_password_hash TEXT DEFAULT NULL) RETURNS BOOLEAN LANGUAGE plpgsql AS $$ DECLARE
user_update BOOLEAN := FALSE;
BEGIN
  -- Update username
  IF input_username IS NOT NULL THEN
    BEGIN
      UPDATE users
      SET username = input_username
      WHERE
        user_id = input_user_id;
      user_update := user_update
      OR FOUND;
    END;
  END IF;
  
  -- Update email
  IF input_email IS NOT NULL THEN
    BEGIN
      UPDATE users
      SET email = input_email
      WHERE
        user_id = input_user_id;
      user_update := user_update
      OR FOUND;
    END;
  END IF;
  
  -- Update password -> might need to be changed during backend as password needs to be hashed there
  IF input_password_hash IS NOT NULL THEN
    UPDATE users
    SET password_hash = input_password_hash
    WHERE
      user_id = input_user_id;
    user_update := user_update
    OR FOUND;
  END IF;
  RETURN user_update;
END;
$$;
-- Delete user
CREATE
OR REPLACE FUNCTION delete_user (input_user_id INT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  DELETE
  FROM
    users
  WHERE
    user_id = input_user_id;
END;
$$;
-- Create bookmark
CREATE
OR REPLACE FUNCTION create_bookmark (input_user_id INT, input_tconst VARCHAR DEFAULT NULL, input_nconst VARCHAR DEFAULT NULL) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO user_bookmarks (user_id, tconst, nconst)
  VALUES
  (input_user_id, input_tconst, input_nconst);
END;
$$;
-- Read bookmarks
CREATE
OR REPLACE FUNCTION read_bookmarks (input_user_id INT) RETURNS TABLE (bookmark_id INT, user_id INT, tconst VARCHAR, nconst VARCHAR, bookmark_time TIMESTAMP) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY SELECT
    u.bookmark_id,
    u.user_id,
    u.tconst,
    u.nconst,
    u.bookmark_time
  FROM
    user_bookmarks u
  WHERE
    u.user_id = input_user_id;
END;
$$;
-- Update bookmark
CREATE
OR REPLACE FUNCTION update_bookmark (input_bookmark_id INT, input_tconst VARCHAR DEFAULT NULL, input_nconst VARCHAR DEFAULT NULL) RETURNS BOOLEAN LANGUAGE plpgsql AS $$ DECLARE
bookmark_update BOOLEAN := FALSE;
BEGIN
  IF input_tconst IS NOT NULL THEN
    UPDATE user_bookmarks
    SET tconst = input_tconst
    WHERE
      bookmark_id = input_bookmark_id;
    bookmark_update := bookmark_update
    OR FOUND;
  END IF;
  IF input_nconst IS NOT NULL THEN
    UPDATE user_bookmarks
    SET nconst = input_nconst
    WHERE
      bookmark_id = input_bookmark_id;
    bookmark_update := bookmark_update
    OR FOUND;
  END IF;
  RETURN bookmark_update;
END;
$$;
-- Delete bookmark
CREATE
OR REPLACE FUNCTION delete_bookmark (input_bookmark_id INT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  DELETE
  FROM
    user_bookmarks
  WHERE
    bookmark_id = input_bookmark_id;
END;
$$;
-- 1-D.2 Simple search
CREATE
OR REPLACE FUNCTION simple_search (input_user_id INT DEFAULT NULL, input_query TEXT DEFAULT NULL) RETURNS TABLE (tconst CHAR(10), title TEXT) LANGUAGE plpgsql AS $$
BEGIN
  -- Log the search if user_id is provided
  IF input_user_id IS NOT NULL THEN
    INSERT INTO user_search_history (user_id, search_term, search_time)
    VALUES
    (input_user_id, input_query, NOW());
  END IF;
  
  -- Return search results
  RETURN QUERY SELECT
    t.tconst,
    t.primarytitle AS title
  FROM
    titles t
  WHERE
    LOWER(t.primarytitle) LIKE LOWER('%' || input_query || '%')
  ORDER BY
    t.primarytitle
    LIMIT 100;
END;
$$;
-- 1-D.3 Title rating
CREATE
OR REPLACE FUNCTION rate (input_user_id INT, input_tconst VARCHAR, input_rating INT) RETURNS VOID LANGUAGE plpgsql AS $$ DECLARE
temp_prev INT;
temp_avg NUMERIC;
temp_votes INT;
BEGIN
  IF input_rating < 1
    OR input_rating > 10 THEN
    RAISE
  EXCEPTION
    'Rating must be between 1 and 10';
  END IF;
  SELECT
    rating INTO temp_prev
  FROM
    user_rating_history
  WHERE
    user_id = input_user_id
    AND tconst = input_tconst
  ORDER BY
    rating_time DESC
    LIMIT 1;
    
  -- If no ratings exists, create a new row for the movie
  INSERT INTO ratings (tconst, averagerating, numvotes)
  VALUES
  (input_tconst, NULL, 0) ON CONFLICT (tconst) DO
    NOTHING;
    SELECT
      averagerating,
      numvotes INTO temp_avg,
      temp_votes
    FROM
      ratings
    WHERE
      tconst = input_tconst;
    IF temp_avg IS NULL THEN
      temp_avg := 0;
    END IF;
    IF temp_votes IS NULL THEN
      temp_votes := 0;
    END IF;
    IF temp_prev IS NULL THEN
      temp_avg := ((temp_avg * temp_votes) + input_rating) :: NUMERIC / NULLIF (temp_votes + 1, 0);
      temp_votes := temp_votes + 1;
    ELSE
      temp_avg := ((temp_avg * temp_votes) - temp_prev + input_rating) :: NUMERIC / NULLIF (temp_votes, 0);
    END IF;
    UPDATE ratings
    SET averagerating = temp_avg,
    numvotes = temp_votes
    WHERE
      tconst = input_tconst;
    IF temp_prev IS NULL THEN
      INSERT INTO user_rating_history (user_id, tconst, rating)
      VALUES
      (input_user_id, input_tconst, input_rating);
    ELSE
      UPDATE user_rating_history
      SET rating = input_rating,
      rating_time = NOW()
      WHERE
        user_id = input_user_id
        AND tconst = input_tconst;
    END IF;
  END;
  $$;
  -- 1-D.4 Structured search
  CREATE
  OR REPLACE FUNCTION structured_string_search (input_user_id INT DEFAULT NULL, input_title TEXT DEFAULT NULL, input_plot TEXT DEFAULT NULL, input_characters TEXT DEFAULT NULL, input_person_name TEXT DEFAULT NULL) RETURNS TABLE (tconst VARCHAR, title TEXT) LANGUAGE plpgsql AS $$
  BEGIN
    -- Log the search directly into user_search_history
		IF input_user_id IS NOT NULL THEN
    INSERT INTO user_search_history (user_id, search_term, search_time)
    VALUES
    (input_user_id, concat_ws (' | ', input_title, input_plot, input_characters, input_person_name), NOW()); -- i dont think we need now because we have it in the creation of the table
    END IF;
    
    RETURN QUERY WITH candidate_titles AS (
      SELECT
        t.tconst,
        t.primarytitle AS title
      FROM
        titles t
        LEFT JOIN title_extras te ON te.tconst = t.tconst
      WHERE
        (input_title IS NULL OR LOWER(t.primarytitle) LIKE LOWER('%' || input_title || '%')) -- case sensitive?
        AND (
          input_plot IS NULL
          OR (te.plot IS NOT NULL AND LOWER(te.plot) LIKE LOWER('%' || input_plot || '%'))
        )
    ),
    char_filtered AS (
      SELECT DISTINCT
        ct.tconst,
        ct.title
      FROM
        candidate_titles ct
        LEFT JOIN participates_in_title pit ON pit.tconst = ct.tconst
      WHERE
        input_characters IS NULL
        OR (
          pit.CHARACTERS IS NOT NULL
          AND LOWER(regexinput_replace (pit.CHARACTERS, '[\[\]"]', '', 'g')) LIKE LOWER('%' || input_characters || '%')
        )
    ),
    person_filtered AS (
      SELECT DISTINCT
        cf.tconst,
        cf.title
      FROM
        char_filtered cf
        LEFT JOIN participates_in_title pit2 ON pit2.tconst = cf.tconst
        LEFT JOIN persons n ON n.nconst = pit2.nconst
      WHERE
        input_person_name IS NULL
        OR (n.primaryname IS NOT NULL AND LOWER(n.primaryname) LIKE LOWER('%' || input_person_name || '%'))
    ) SELECT
      tconst,
      title
    FROM
      person_filtered
    ORDER BY
      title
      LIMIT 500;
  END;
  $$;
  -- 1_D.5 Finding Names
  CREATE
  OR REPLACE FUNCTION name_search (input_user_id INT, input_query TEXT) RETURNS TABLE (nconst CHAR(10), primaryname VARCHAR(256)) LANGUAGE plpgsql AS $$
  BEGIN
    IF input_user_id IS NOT NULL THEN
      INSERT INTO user_search_history (user_id, search_term, search_time)
      VALUES
      (input_user_id, input_query, NOW());
    END IF;
    RETURN QUERY SELECT
      n.nconst,
      n.primaryname
    FROM
      persons n
    WHERE
      LOWER(n.primaryname) LIKE LOWER('%' || input_query || '%')
    ORDER BY
      n.primaryname
      LIMIT 100;
  END;
  $$;
  -- 1_D.6 Finding co-players
  CREATE
  OR REPLACE FUNCTION co_players (input_name TEXT) RETURNS TABLE (nconst CHAR(10), primaryname VARCHAR(256), frequency BIGINT) LANGUAGE plpgsql AS $$
  BEGIN
    RETURN QUERY WITH TARGET AS (
      SELECT DISTINCT
        pit.tconst
      FROM
        persons n
        JOIN participates_in_title pit ON pit.nconst = n.nconst
      WHERE
        LOWER(n.primaryname) LIKE LOWER('%' || input_name || '%')
    ) SELECT
      n2.nconst,
      n2.primaryname,
      COUNT(*) AS frequency
    FROM
      TARGET t
      JOIN participates_in_title pit2 ON pit2.tconst = t.tconst
      JOIN persons n2 ON n2.nconst = pit2.nconst
    WHERE
      LOWER(n2.primaryname) <> LOWER(input_name)
    GROUP BY
      n2.nconst,
      n2.primaryname
    ORDER BY
      frequency DESC,
      n2.primaryname
      LIMIT 20;
  END;
  $$;
  -- 1_D.7 Name rating
CREATE OR REPLACE FUNCTION update_name_rating (input_nconst VARCHAR(10))
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO name_ratings (nconst, weighted_rating)
  SELECT
    pit.nconst,
		SUM(r.averagerating * r.numvotes)::NUMERIC / NULLIF(SUM(r.numvotes), 0)
  FROM participates_in_title pit
  JOIN ratings r ON r.tconst = pit.tconst
  WHERE pit.nconst = input_nconst
  GROUP BY pit.nconst;
END;
$$;
    -- 1_D.8 Popular actors
    CREATE
    OR REPLACE FUNCTION popular_actors (input_tconst VARCHAR) RETURNS TABLE (nconst CHAR(10), primaryname VARCHAR(256), popularity NUMERIC) LANGUAGE plpgsql AS $$
    BEGIN
      RETURN QUERY SELECT pr.nconst,
        pr.primaryname,
        nr.weighted_rating::NUMERIC AS popularity
      FROM
        participates_in_title pit
        JOIN persons pr ON pr.nconst = pit.nconst
        LEFT JOIN name_ratings nr ON nr.nconst = pr.nconst
      WHERE
        pit.tconst = input_tconst
      ORDER BY
        nr.weighted_rating DESC NULLS LAST,
        pr.primaryname;
    END;
    $$;
    -- 1_D.9 Similar movies
CREATE OR REPLACE FUNCTION similar_movies (input_tconst VARCHAR)
RETURNS TABLE (
  tconst CHAR(10),
  title TEXT,
  similarity BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH movie_genres AS (
    SELECT DISTINCT genre
    FROM title_genre
    WHERE title_genre.tconst = input_tconst  
  )
  SELECT
    t.tconst,
    t.primarytitle,
    COUNT(DISTINCT tg.genre) AS similarity
  FROM titles t
  JOIN title_genre tg ON tg.tconst = t.tconst
  JOIN movie_genres mg ON mg.genre = tg.genre
  WHERE t.tconst <> input_tconst
  GROUP BY t.tconst, t.primarytitle
  HAVING COUNT(DISTINCT tg.genre) > 0
  ORDER BY similarity DESC, t.primarytitle
  LIMIT 20;
END;
$$;
    
    -- 1_D.10 Frequent person words
    CREATE
    OR REPLACE FUNCTION person_words (input_name TEXT, input_limit INT DEFAULT 10) RETURNS TABLE (word TEXT, frequency INT) LANGUAGE plpgsql AS $$
    BEGIN
      RETURN QUERY WITH target_person AS (SELECT nconst FROM persons WHERE LOWER(primaryname) LIKE LOWER('%' || input_name || '%')),
      related_titles AS (SELECT DISTINCT pit.tconst FROM participates_in_title pit JOIN target_person tp ON tp.nconst = pit.nconst),
      words AS (SELECT wi.word FROM word_index wi JOIN related_titles rt ON rt.tconst = wi.tconst) SELECT
        w.word,
        COUNT(*) AS frequency
      FROM
        words w
      GROUP BY
        w.word
      ORDER BY
        frequency DESC,
        w.word
        LIMIT input_limit;
    END;
    $$;
    -- 1_D.11 Exact-match querying
    CREATE
    OR REPLACE FUNCTION query_match (input_keywords TEXT []) RETURNS TABLE (tconst CHAR(10), title TEXT) LANGUAGE plpgsql AS $$
    BEGIN
      RETURN QUERY SELECT
        t.tconst,
        t.primarytitle
      FROM
        word_index wi
        JOIN titles t ON t.tconst = wi.tconst
      WHERE
        wi.word = ANY (input_keywords)
      GROUP BY
        t.tconst,
        t.primarytitle
      HAVING
        COUNT(DISTINCT wi.word) = array_length(input_keywords, 1)
      ORDER BY
        t.primarytitle
        LIMIT 100;
    END;
    $$;
    -- 1_D.12 Best-match querying
    CREATE
    OR REPLACE FUNCTION query_best_match (input_keywords TEXT [], input_limit INT DEFAULT 100) RETURNS TABLE (tconst CHAR(10), title TEXT, RANK INT) LANGUAGE plpgsql AS $$
    BEGIN
      RETURN QUERY SELECT
        t.tconst,
        t.primarytitle,
        COUNT(DISTINCT wi.word) AS RANK
      FROM
        word_index wi
        JOIN titles t ON t.tconst = wi.tconst
      WHERE
        wi.word = ANY (input_keywords)
      GROUP BY
        t.tconst,
        t.primarytitle
      ORDER BY
        RANK DESC,
        t.primarytitle
        LIMIT input_limit;
    END;
    $$;
    -- 1_D.13 Word-to-words querying
    CREATE
    OR REPLACE FUNCTION query_word_to_words (input_keywords TEXT [], input_limit INT DEFAULT 20) RETURNS TABLE (word TEXT, frequency INT) LANGUAGE plpgsql AS $$
    BEGIN
      RETURN QUERY WITH matched_titles AS (SELECT DISTINCT wi.tconst FROM word_index wi WHERE wi.word = ANY (input_keywords)),
      collected_words AS (
        SELECT
          wi.word
        FROM
          word_index wi
          JOIN matched_titles mt ON mt.tconst = wi.tconst
        WHERE
          wi.word <> ALL (input_keywords) -- exclude the query words themselves
      ) SELECT
        word,
        COUNT(*) AS frequency
      FROM
        collected_words
      GROUP BY
        word
      ORDER BY
        frequency DESC,
        word
        LIMIT input_limit;
    END;
    $$;