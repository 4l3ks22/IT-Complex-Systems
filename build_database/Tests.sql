-- Create users
SELECT create_user('alin', 'alin@eugen.com', 'romania');  -- should return True
SELECT create_user('alexander', 'alin@eugen.com', 'slovakia');  -- should return false due to violation

-- Read user
SELECT * FROM read_user('alin');

-- Update user
SELECT update_user(1, 'alin', NULL, NULL);  -- should return false cannot have nulls - had problem with duplicate keys so had to fix the function

-- Delete user
SELECT delete_user(1);  -- should delete user
SELECT delete_user(99);  -- should return false as 99 doesn't exist
