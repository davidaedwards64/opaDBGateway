USE employee_directory;

INSERT INTO employees (first_name, last_name, email, phone, department, job_title) VALUES
('Sarah',   'Anderson',  'sarah.anderson@example.com',  '555-201-1001', 'Engineering',  'Senior Software Engineer'),
('Michael', 'Chen',      'michael.chen@example.com',    '555-201-1002', 'Engineering',  'Backend Engineer'),
('Emily',   'Rodriguez', 'emily.rodriguez@example.com', '555-201-1003', 'Product',      'Product Manager'),
('James',   'Williams',  'james.williams@example.com',  '555-201-1004', 'Engineering',  'DevOps Engineer'),
('Priya',   'Patel',     'priya.patel@example.com',     '555-201-1005', 'Marketing',    'Marketing Director'),
('David',   'Kim',       'david.kim@example.com',       '555-201-1006', 'Sales',        'Account Executive'),
('Laura',   'Thompson',  'laura.thompson@example.com',  '555-201-1007', 'HR',           'HR Manager'),
('Carlos',  'Gomez',     'carlos.gomez@example.com',    '555-201-1008', 'Finance',      'Financial Analyst'),
('Megan',   'Foster',    'megan.foster@example.com',    '555-201-1009', 'Product',      'UX Designer'),
('Kevin',   'Nguyen',    'kevin.nguyen@example.com',    '555-201-1010', 'Engineering',  'Frontend Engineer'),
('Rachel',  'Stewart',   'rachel.stewart@example.com',  '555-201-1011', 'Operations',   'Operations Manager'),
('Daniel',  'Brown',     'daniel.brown@example.com',    '555-201-1012', 'Sales',        'Sales Manager'),
('Jessica', 'Lee',       'jessica.lee@example.com',     '555-201-1013', 'IT',           'Systems Administrator'),
('Brian',   'Martinez',  'brian.martinez@example.com',  '555-201-1014', 'Finance',      'Controller'),
('Amanda',  'Wilson',    'amanda.wilson@example.com',   '555-201-1015', 'Marketing',    'Content Strategist');

INSERT INTO logins (employee_id, username, fullname, password)
SELECT id,
       email,
       CONCAT(first_name, ' ', last_name),
       LEFT(MD5(UUID()), 16)
FROM employees;
