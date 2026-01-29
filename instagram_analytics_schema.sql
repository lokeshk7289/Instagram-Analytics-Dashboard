-- File: instagram_analytics_schema.sql

-- Create Database
CREATE DATABASE IF NOT EXISTS instagram_analytics;
USE instagram_analytics;

-- 1. Posts Table (Main content data)
CREATE TABLE posts (
    post_id INT PRIMARY KEY AUTO_INCREMENT,
    post_type ENUM('image', 'reel', 'carousel') NOT NULL,
    caption TEXT,
    post_date DATETIME NOT NULL,
    likes INT DEFAULT 0,
    comments INT DEFAULT 0,
    shares INT DEFAULT 0,
    saves INT DEFAULT 0,
    reach INT DEFAULT 0,
    impressions INT DEFAULT 0,
    hashtags JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_post_date (post_date),
    INDEX idx_post_type (post_type),
    INDEX idx_engagement (likes, comments)
) ENGINE=InnoDB;

-- 2. Followers Table (Growth tracking)
CREATE TABLE followers (
    record_id INT PRIMARY KEY AUTO_INCREMENT,
    record_date DATE NOT NULL,
    followers_gained INT DEFAULT 0,
    followers_lost INT DEFAULT 0,
    total_followers INT NOT NULL,
    UNIQUE KEY unique_date (record_date),
    INDEX idx_record_date (record_date)
) ENGINE=InnoDB;

-- 3. Engagement Metrics Table
CREATE TABLE engagement_metrics (
    metric_id INT PRIMARY KEY AUTO_INCREMENT,
    post_id INT NOT NULL,
    engagement_rate DECIMAL(5,2),
    profile_visits INT DEFAULT 0,
    website_clicks INT DEFAULT 0,
    created_date DATE NOT NULL,
    FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
    INDEX idx_post_engagement (post_id, created_date),
    INDEX idx_engagement_date (created_date)
) ENGINE=InnoDB;

-- 4. Post Performance Summary View
CREATE VIEW post_performance_summary AS
SELECT 
    p.post_id,
    p.post_type,
    DATE(p.post_date) as post_day,
    HOUR(p.post_date) as post_hour,
    DAYNAME(p.post_date) as day_name,
    p.likes,
    p.comments,
    p.shares,
    p.saves,
    p.reach,
    p.impressions,
    e.engagement_rate,
    e.profile_visits,
    e.website_clicks,
    -- Calculate total engagement
    (p.likes + p.comments + p.shares + p.saves) as total_engagement,
    -- Calculate engagement rate if not provided
    CASE 
        WHEN p.reach > 0 THEN 
            ROUND(((p.likes + p.comments + p.shares + p.saves) / p.reach) * 100, 2)
        ELSE 0 
    END as calculated_engagement_rate
FROM posts p
LEFT JOIN engagement_metrics e ON p.post_id = e.post_id;

-- 5. Follower Growth Trends View
CREATE VIEW follower_growth_trends AS
WITH daily_growth AS (
    SELECT 
        record_date,
        total_followers,
        followers_gained,
        followers_lost,
        followers_gained - followers_lost as net_growth,
        -- 7-day moving average
        AVG(followers_gained - followers_lost) OVER (
            ORDER BY record_date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) as weekly_avg_growth,
        -- Running total
        SUM(followers_gained - followers_lost) OVER (
            ORDER BY record_date
        ) as cumulative_growth
    FROM followers
)
SELECT * FROM daily_growth;

-- 6. Hashtag Performance View
CREATE VIEW hashtag_performance AS
SELECT 
    hashtag,
    COUNT(*) as usage_count,
    AVG(p.likes) as avg_likes,
    AVG(p.comments) as avg_comments,
    AVG(p.shares) as avg_shares,
    AVG(p.saves) as avg_saves,
    AVG(p.reach) as avg_reach,
    ROUND(AVG(p.likes + p.comments + p.shares + p.saves), 2) as avg_total_engagement
FROM posts p,
JSON_TABLE(
    p.hashtags,
    '$[*]' COLUMNS(hashtag VARCHAR(50) PATH '$')
) AS hashtags
GROUP BY hashtag
ORDER BY avg_total_engagement DESC;

-- 7. Content Type Performance View
CREATE VIEW content_type_performance AS
SELECT 
    post_type,
    COUNT(*) as post_count,
    ROUND(AVG(likes), 2) as avg_likes,
    ROUND(AVG(comments), 2) as avg_comments,
    ROUND(AVG(shares), 2) as avg_shares,
    ROUND(AVG(saves), 2) as avg_saves,
    ROUND(AVG(reach), 2) as avg_reach,
    ROUND(AVG(impressions), 2) as avg_impressions,
    ROUND(AVG(
        (likes + comments + shares + saves) / NULLIF(reach, 0) * 100
    ), 2) as avg_engagement_rate,
    SUM(likes + comments + shares + saves) as total_engagement
FROM posts
GROUP BY post_type
ORDER BY avg_engagement_rate DESC;

-- 8. Best Posting Times View
CREATE VIEW best_posting_times AS
SELECT 
    DAYNAME(post_date) as day_of_week,
    HOUR(post_date) as hour_of_day,
    COUNT(*) as post_count,
    ROUND(AVG(likes), 2) as avg_likes,
    ROUND(AVG(comments), 2) as avg_comments,
    ROUND(AVG(reach), 2) as avg_reach,
    ROUND(AVG(
        (likes + comments + shares + saves) / NULLIF(reach, 0) * 100
    ), 2) as avg_engagement_rate,
    RANK() OVER (
        ORDER BY AVG((likes + comments + shares + saves) / NULLIF(reach, 0) * 100) DESC
    ) as engagement_rank
FROM posts
GROUP BY DAYNAME(post_date), HOUR(post_date)
HAVING post_count >= 3;