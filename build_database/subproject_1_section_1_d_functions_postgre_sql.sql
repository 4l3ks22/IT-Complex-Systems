-- 1-D.1 Framework support

-- Create user function
CREATE
OR REPLACE FUNCTION create_user (p_username VARCHAR, p_email VARCHAR, p_password_hash TEXT) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO users (username, email, password_hash)
  VALUES
  (p_username, p_email, p_password_hash);
  RETURN TRUE;
EXCEPTION
  WHEN unique_violation THEN
    RETURN FALSE;
  WHEN OTHERS THEN
    RETURN FALSE;
  END;
  $$;
  
-- Read users function
  CREATE
  OR REPLACE FUNCTION read_user (p_username VARCHAR) RETURNS TABLE (user_id INT, username VARCHAR, email VARCHAR, password_hash TEXT, creation_time TIMESTAMP) LANGUAGE plpgsql AS $$
  BEGIN
    RETURN query SELECT
      user_id,
      username,
      email,
      password_hash,
      creation_time
    FROM
      users
    WHERE
      p_username = username;
  END;
  $$;
  
-- Update user function 
  CREATE
  OR REPLACE FUNCTION update_user_information (p_user_id INT, p_username VARCHAR DEFAULT NULL, p_email VARCHAR DEFAULT NULL, p_password_hash TEXT DEFAULT NULL) RETURNS BOOLEAN LANGUAGE plpgsql AS $$ DECLARE
  any_changed BOOLEAN := FALSE;
  BEGIN
    IF p_username IS NOT NULL THEN
      UPDATE users
      SET username = p_username
      WHERE
        user_id = p_user_id;
      any_changed := any_changed
      OR FOUND; --FOUND = true if the UPDATE hit a row
    END IF;
    IF p_email IS NOT NULL THEN
      UPDATE users
      SET email = p_email
      WHERE
        user_id = p_user_id;
      any_changed := any_changed
      OR FOUND; --FOUND = true if the UPDATE hit a row
    END IF;
    IF p_password_hash IS NOT NULL THEN
      UPDATE users
      SET password_hash = p_password_hash
      WHERE
        user_id = p_user_id;
      any_changed := any_changed
      OR FOUND; --FOUND = true if the UPDATE hit a row
    END IF;
    
    RETURN any_changed; --true if at least one field was updated
    END;
    $$;

-- Delete user function
CREATE OR REPLACE FUNCTION delete_user(p_user_id int) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM users WHERE user_id = p_user_id;
  RETURN FOUND; -- special boolean variable built-in. true if user existed and deleted, false otherwise
END;
$$;


-- 1-D.1 Creating functions for managing bookmarking names and titles (add a title or name to user’s bookmarks). CRUD (Create, Read, Update, Delete)

-- Create bookmark function
CREATE OR REPLACE FUNCTION create_bookmark(
    p_user_id INT,
    p_title_id VARCHAR DEFAULT NULL,
    p_name_id VARCHAR DEFAULT NULL
) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO user_bookmarks (user_id, tconst, nconst)
  VALUES (p_user_id, p_title_id, p_name_id);

  RETURN TRUE;

EXCEPTION
  WHEN unique_violation THEN
    RETURN FALSE; -- user already bookmarked same item
  WHEN others THEN
    RETURN FALSE;
END;
$$;

-- Read bookmarks function
CREATE OR REPLACE FUNCTION read_bookmarks(p_user_id INT)
RETURNS TABLE(
    bookmark_id INT,
    user_id INT,
    tconst VARCHAR,
    nconst VARCHAR,
    bookmark_time TIMESTAMP
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT bookmark_id, user_id, tconst, nconst, bookmark_time
  FROM user_bookmarks
  WHERE user_id = p_user_id;
END;
$$;

-- Update bookmark function
CREATE OR REPLACE FUNCTION update_bookmark(
    p_bookmark_id INT,
    p_title_id VARCHAR DEFAULT NULL,
    p_name_id VARCHAR DEFAULT NULL
) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
  DECLARE
  any_changed BOOLEAN := FALSE;
  BEGIN
    IF p_title_id IS NOT NULL THEN
      UPDATE user_bookmarks
      SET tconst = p_title_id
      WHERE
        user_id = p_user_id;
      any_changed := any_changed
      OR FOUND; -- FOUND = true if the UPDATE hit a row
    ELSIF p_name_id IS NOT NULL THEN
      UPDATE user_bookmarks
      SET nconst = p_nconst
      WHERE
        user_id = p_user_id;
      any_changed := any_changed
      OR FOUND; -- FOUND = true if the UPDATE hit a row
    END IF;
    
    RETURN any_changed; -- true if at least one field was updated
  
END;
$$;


-- Delete bookmark function
CREATE OR REPLACE FUNCTION delete_bookmark(p_bookmark_id INT)
RETURNS BOOLEAN LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM user_bookmarks
  WHERE bookmark_id = p_bookmark_id;

  RETURN FOUND; -- TRUE if deleted, FALSE if not
END;
$$;


-- 1-D.2 Simple search

CREATE OR REPLACE FUNCTION string_search(p_user_id int, p_query text)
RETURNS TABLE(tconst varchar, title text) 
LANGUAGE plpgsql AS $$
BEGIN
  -- Only log if user_id exists
  IF p_user_id IS NOT NULL THEN
    INSERT INTO user_search_history(user_id, search_term, search_time)
    VALUES (p_user_id, p_query, now());
  END IF;

  RETURN QUERY
SELECT t.tconst::varchar, t.primarytitle
FROM titles t
LEFT JOIN title_extras te ON te.tconst = t.tconst
WHERE lower(t.primarytitle) LIKE lower('%' || p_query || '%')
   OR (te.plot IS NOT NULL AND lower(te.plot) LIKE lower('%' || p_query || '%'))
ORDER BY t.primarytitle
LIMIT 100;
END$$;

-- 1-D.3 Title Rating
CREATE OR REPLACE FUNCTION rate(user_id int, p_tconst varchar, p_rating int)
RETURNS void LANGUAGE plpgsql AS $$ -- doesn't have return just updates ratings
DECLARE v_prev int; v_avg numeric; v_votes int; -- temporary values for updates on tables
BEGIN
  IF p_rating < 1 OR p_rating > 10 THEN RAISE EXCEPTION 'Rating must be between 1 and 10'; END IF; -- rating must be between 1 and 10

  SELECT rating INTO v_prev FROM user_rating_history WHERE user_id = user_id AND tconst = p_tconst ORDER BY rating_time DESC LIMIT 1;

  INSERT INTO ratings(tconst, averagerating, numvotes)
  VALUES (p_tconst, NULL, 0)
  ON CONFLICT (tconst) DO NOTHING;

  SELECT averagerating, numvotes INTO v_avg, v_votes FROM ratings WHERE tconst = p_tconst;
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
    INSERT INTO user_rating_history(user_id, title_id, rating) VALUES (user_id, p_tconst, p_rating);
  ELSE
    UPDATE user_rating_history
      SET rating = p_rating, rating_time = now()
      WHERE user_id = user_id AND title_id = p_tconst;
  END IF;
END$$;

-- 1_D.4 Structured string search

CREATE OR REPLACE FUNCTION structured_string_search(
  p_user_id int,
  p_title text,
  p_plot text,
  p_characters text,
  p_person_name text
) 
RETURNS TABLE(tconst varchar, title text)
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM log_search(p_user_id, concat_ws(' | ', p_title, p_plot, p_characters, p_person_name));

  RETURN QUERY
  WITH candidate_titles AS (
    SELECT t.tconst::varchar, t.primarytitle AS title
    FROM titles t
    LEFT JOIN title_extras te ON te.tconst = t.tconst
    WHERE (p_title IS NULL OR lower(t.primarytitle) LIKE lower('%' || p_title || '%'))
      AND (p_plot IS NULL OR (te.plot IS NOT NULL AND lower(te.plot) LIKE lower('%' || p_plot || '%')))
  ), char_filtered AS (
    SELECT DISTINCT ct.tconst, ct.title
    FROM candidate_titles ct
    LEFT JOIN principals pr ON pr.tconst = ct.tconst
    WHERE p_characters IS NULL 
       OR (pr.characters IS NOT NULL AND lower(regexp_replace(pr.characters, '[\[\]"]', '', 'g')) LIKE lower('%' || p_characters || '%'))
  ), person_filtered AS (
    SELECT DISTINCT cf.tconst, cf.title
    FROM char_filtered cf
    LEFT JOIN principals tp ON tp.tconst = cf.tconst
    LEFT JOIN persons n ON n.nconst = tp.nconst
    WHERE p_person_name IS NULL 
       OR (n.primaryname IS NOT NULL AND lower(n.primaryname) LIKE lower('%' || p_person_name || '%'))
  )
  SELECT tconst, title 
  FROM person_filtered 
  ORDER BY title 
  LIMIT 500;
END$$;


-- 1_D.6 Finding co-players
CREATE OR REPLACE FUNCTION co_players(p_name text)
RETURNS TABLE(nconst varchar, primaryname text, frequency int)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  WITH target AS (
    SELECT DISTINCT pr.tconst
    FROM persons n
    JOIN principals pr ON pr.nconst = n.nconst
    WHERE lower(n.primaryname) LIKE lower('%' || p_name || '%')
  )
  SELECT n2.nconst::varchar, n2.primaryname, COUNT(*) AS frequency
  FROM target t
  JOIN principals pr2 ON pr2.tconst = t.tconst
  JOIN persons n2 ON n2.nconst = pr2.nconst
  WHERE lower(n2.primaryname) <> lower(p_name)
  GROUP BY n2.nconst, n2.primaryname
  ORDER BY frequency DESC, n2.primaryname
  LIMIT 20;
END$$;

-- 1_D.7 Name rating
CREATE OR REPLACE FUNCTION update_name_rating(p_nconst varchar)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO name_ratings(nconst, weighted_rating)
  SELECT pr.nconst,
         SUM(r.averagerating * r.numvotes)::numeric / NULLIF(SUM(r.numvotes), 0)
  FROM principals pr
  JOIN ratings r ON r.tconst = pr.tconst
  WHERE pr.nconst = p_nconst
  GROUP BY pr.nconst
  ON CONFLICT (nconst) DO UPDATE
  SET weighted_rating = EXCLUDED.weighted_rating;
END$$;

-- 1_D.8 Popular actors
CREATE OR REPLACE FUNCTION popular_actors(p_tconst varchar)
RETURNS TABLE(nconst varchar, primaryname text, popularity numeric)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT n.nconst::varchar, n.primaryname, nr.rating AS popularity
  FROM principals pr
  JOIN persons n ON n.nconst = pr.nconst
  LEFT JOIN name_ratings nr ON nr.nconst = n.nconst
  WHERE pr.tconst = p_tconst::char(10)
  ORDER BY nr.rating DESC NULLS LAST, n.primaryname;
END$$;

-- 1_D.9 Similar movies
CREATE OR REPLACE FUNCTION similar_movies_by_genre(p_tconst varchar)
RETURNS TABLE(tconst varchar, title text, similarity int)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  WITH movie_genres AS (
    SELECT genre
    FROM title_genres
    WHERE tconst = p_tconst::char(10) -- match storage type
  )
  SELECT t.tconst::varchar, t.primarytitle, COUNT(*) AS similarity
  FROM titles t
  JOIN title_genres tg ON tg.tconst = t.tconst
  JOIN movie_genres mg ON mg.genre = tg.genre
  WHERE t.tconst <> p_tconst::char(10)
  GROUP BY t.tconst, t.primarytitle
  ORDER BY similarity DESC, t.primarytitle
  LIMIT 20;
END$$;


-- 1_D10 Frequent person words

-- 1_D11 Exact-match querying 

-- 1_D12 Best-match querying

-- 1_D13 word-to-words querying