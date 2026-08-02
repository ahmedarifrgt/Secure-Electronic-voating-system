-- ---------------------------------------------------------------------------
-- Secure Electronic Voting System — Full Database Schema
-- ---------------------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS voting_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE voting_system;

-- ---------------------------------------------------------------------------
-- Voters
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS voters (
    voter_id INT AUTO_INCREMENT PRIMARY KEY,
    nid VARCHAR(20) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    father_name VARCHAR(100),
    mother_name VARCHAR(100),
    dob DATE NOT NULL,
    gender ENUM('Male','Female','Other'),
    mobile VARCHAR(15),
    email VARCHAR(100),
    permanent_address TEXT,
    present_address TEXT,
    area_code VARCHAR(10),
    constituency VARCHAR(50),
    face_image_path VARCHAR(255),
    face_embedding VARBINARY(512),
    registration_status BOOLEAN DEFAULT FALSE,
    eligibility_status BOOLEAN DEFAULT FALSE,
    has_voted BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMP NULL,
    account_status ENUM('Active','Inactive') DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_voters_nid (nid),
    INDEX idx_voters_area (area_code, constituency),
    INDEX idx_voters_status (account_status, eligibility_status)
);

-- ---------------------------------------------------------------------------
-- Elections
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS elections (
    election_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    area_code VARCHAR(10),
    constituency VARCHAR(50),
    start_date DATETIME NOT NULL,
    end_date DATETIME NOT NULL,
    status ENUM('Upcoming','Active','Completed') DEFAULT 'Upcoming',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_elections_status (status),
    INDEX idx_elections_area (area_code, constituency)
);

-- ---------------------------------------------------------------------------
-- Candidates
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS candidates (
    candidate_id INT AUTO_INCREMENT PRIMARY KEY,
    election_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    party VARCHAR(100),
    symbol VARCHAR(100),
    area_code VARCHAR(10),
    constituency VARCHAR(50),
    status ENUM('Active','Withdrawn') DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (election_id) REFERENCES elections(election_id) ON DELETE CASCADE,
    INDEX idx_candidates_election (election_id)
);

-- ---------------------------------------------------------------------------
-- Votes (encrypted, hashed, signed — never plaintext)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS votes (
    vote_id INT AUTO_INCREMENT PRIMARY KEY,
    election_id INT NOT NULL,
    voter_id INT NOT NULL,
    candidate_id INT,
    encrypted_vote LONGBLOB NOT NULL,
    hash VARCHAR(64) NOT NULL,
    signature TEXT NOT NULL,
    iv VARCHAR(64) NOT NULL,
    token VARCHAR(64) UNIQUE NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (election_id) REFERENCES elections(election_id) ON DELETE CASCADE,
    FOREIGN KEY (voter_id) REFERENCES voters(voter_id) ON DELETE CASCADE,
    UNIQUE KEY uq_voter_election (voter_id, election_id),
    INDEX idx_votes_election (election_id),
    INDEX idx_votes_voter (voter_id)
);

-- ---------------------------------------------------------------------------
-- Face verification / authentication logs
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS face_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    voter_id INT,
    nid VARCHAR(20),
    stage VARCHAR(50),
    status ENUM('Success','Failed','Skipped') DEFAULT 'Skipped',
    confidence DECIMAL(6,4),
    details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (voter_id) REFERENCES voters(voter_id) ON DELETE SET NULL,
    INDEX idx_face_logs_voter (voter_id),
    INDEX idx_face_logs_stage (stage)
);

-- ---------------------------------------------------------------------------
-- Security events (spoof attempts, SQLi/XSS attempts, rate-limit hits)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS security_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    event VARCHAR(100) NOT NULL,
    severity ENUM('Info','Warning','Critical') DEFAULT 'Info',
    ip_address VARCHAR(45),
    details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_security_logs_event (event),
    INDEX idx_security_logs_time (created_at)
);

-- ---------------------------------------------------------------------------
-- Audit logs (every sensitive action)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    actor_type ENUM('voter','admin','system') DEFAULT 'system',
    actor_id INT,
    action VARCHAR(100) NOT NULL,
    details TEXT,
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_audit_logs_actor (actor_type, actor_id),
    INDEX idx_audit_logs_action (action),
    INDEX idx_audit_logs_time (created_at)
);

