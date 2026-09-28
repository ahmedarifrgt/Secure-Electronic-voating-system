# Thesis Index: Secure Electronic Voting System

## 1. Introduction
1.1 Background and motivation
1.2 Problem statement
1.3 Objectives of the thesis
1.4 Scope and limitations
1.5 Research questions
1.6 Structure of the thesis

## 2. Literature Review
2.1 Electronic voting systems overview
2.2 Biometric voter authentication
2.3 Face recognition in security systems
2.4 Liveness detection and anti-spoofing
2.5 Deep learning face verification models
2.6 Related work on secure voting and auditability
2.7 Summary of gaps and research contribution

## 3. System Requirements and Analysis
3.1 Functional requirements
3.1.1 Voter registration and enrollment
3.1.2 Admin dashboard and voter management
3.1.3 Voter login and face verification
3.1.4 Vote casting, storage, and retrieval
3.1.5 Reporting and results publication
3.2 Non-functional requirements
3.2.1 Security and privacy
3.2.2 Performance and scalability
3.2.3 Reliability and availability
3.2.4 Usability and accessibility
3.2.5 Maintainability and extensibility
3.3 Threat model and adversary analysis
3.3.1 Threats to voter identity and authentication
3.3.2 Spoofing, replay, and deepfake attacks
3.3.3 Data integrity and tampering threats
3.3.4 Network and API attack surfaces
3.3.5 Insider and administrative threats

## 4. System Architecture
4.1 Overall system architecture
4.1.1 Backend service structure
4.1.2 Frontend application structure
4.1.3 Database schema and data flow
4.1.4 Deployment architecture and Docker support
4.2 Backend components
4.2.1 Flask application and API routes
4.2.2 Authentication and authorization services
4.2.3 Voter registration and camera capture
4.2.4 Face verification pipeline services
4.2.5 Logging, auditing, and security event tracking
4.3 Frontend components
4.3.1 Flutter mobile/web app
4.3.2 Admin panel and voter creation UI
4.3.3 Camera capture and live image upload
4.3.4 Verification feedback and status reporting
4.4 Data storage and persistence
4.4.1 MySQL database
4.4.2 Voter model and face embedding storage
4.4.3 Face image storage and registered face directory
4.4.4 Temporary upload directory and session handling

## 5. Face Verification and Biometric Pipeline
5.1 Face detection and tracking
5.1.1 MediaPipe face mesh and landmark estimation
5.1.2 RetinaFace detector backend
5.1.3 OpenCV Haar cascades fallback
5.1.4 MTCNN and SSD options
5.1.5 Face tracking and single-face validation
5.2 Image quality assessment
5.2.1 Brightness, sharpness, and exposure checks
5.2.2 Face size and centering heuristics
5.2.3 Resolution and capture quality rules
5.3 Liveness detection
5.3.1 Motion analysis across frames
5.3.2 Blink detection using EAR heuristics
5.3.3 Live capture enforcement and frame count
5.4 Anti-spoofing
5.4.1 Replay attack heuristics
5.4.2 Sharpness and Laplacian variance
5.4.3 Moire-pattern detection and printout checks
5.4.4 Mask, crop, and print spoof detection
5.5 Deepfake detection
5.5.1 Deepfake risk and detection strategies
5.5.2 Integration with face verification pipeline
5.5.3 Security impact of deepfake checks
5.6 Face alignment and embedding generation
5.6.1 DeepFace.represent() for embeddings
5.6.2 Alignment and detector backend options
5.6.3 Embedding dimensionality and normalization
5.7 Verification and similarity scoring
5.7.1 DeepFace.verify() 1:1 verification
5.7.2 Distance metrics: Cosine, Euclidean, Euclidean L2
5.7.3 Threshold evaluation and pass/fail decision
5.7.4 Stored embedding reuse to avoid recomputation
5.7.5 Confidence score computation and interpretation

## 6. DeepFace Configuration and Model Selection
6.1 DeepFace overview and role in the system
6.2 Recognition model options
6.2.1 ArcFace (recommended)
6.2.2 FaceNet
6.2.3 GhostFaceNet
6.2.4 SFace
6.2.5 VGG-Face (optional)
6.3 Detector backend options
6.3.1 RetinaFace
6.3.2 MediaPipe
6.3.3 OpenCV
6.3.4 MTCNN
6.3.5 SSD
6.4 Similarity metrics explained
6.4.1 Cosine similarity and cosine distance
6.4.2 Euclidean distance
6.4.3 Euclidean L2 distance
6.5 Configuration management
6.5.1 Environment variables and `backend/config.py`
6.5.2 Default configuration values
6.5.3 Runtime configurability and fallback behavior

## 7. Security Design and Cryptography
7.1 Authentication and authorization
7.1.1 JWT-based auth for admin and voter roles
7.1.2 Token issuance and expiry management
7.1.3 Role-based access control for APIs
7.2 Cryptography and data protection
7.2.1 AES-256 encryption for sensitive data
7.2.2 RSA signature verification and storage
7.2.3 Hashing and integrity checks
7.2.4 Secure key management and environment configuration
7.3 Secure vote casting and storage
7.3.1 Vote encryption and tokenization
7.3.2 Unique vote constraints and double-voting prevention
7.3.3 Audit logs and tamper-evidence
7.4 Logging and monitoring
7.4.1 Face verification stage logging
7.4.2 Security event logs and audit trails
7.4.3 Rate limiting for login and admin actions
7.5 Privacy and data protection
7.5.1 Voter image and biometric data handling
7.5.2 Embedding storage vs raw image storage
7.5.3 Data retention and storage policies

## 8. Implementation Details
8.1 Backend implementation
8.1.1 Flask app initialization and blueprints
8.1.2 Database models and migrations
8.1.3 Service layer and controller layer
8.1.4 Error handling and response design
8.2 Frontend implementation
8.2.1 Flutter project structure
8.2.2 Provider state management
8.2.3 Camera and image upload integration
8.2.4 Admin panel UI and dashboards
8.3 Integration between frontend and backend
8.3.1 HTTP API contract and endpoints
8.3.2 Payload formats and image transfer
8.3.3 Authentication token flow
8.3.4 Error handling and user feedback
8.4 Deployment and environment setup
8.4.1 Docker compose and containerization
8.4.2 Local development setup
8.4.3 Production deployment considerations
8.4.4 Dependency management and requirements

## 9. Evaluation and Testing
9.1 Test strategy
9.1.1 Unit testing for backend services
9.1.2 Integration testing for API routes
9.1.3 End-to-end testing for voter flow
9.1.4 Performance and load testing
9.2 Security evaluation
9.2.1 Threat model validation
9.2.2 Spoofing and attack scenarios
9.2.3 Resilience against deepfake attacks
9.3 Performance evaluation
9.3.1 Face verification latency
9.3.2 Camera capture and live detection speed
9.3.3 Database and query performance
9.4 Usability evaluation
9.4.1 Admin workflow and voter registration
9.4.2 Voter login and verification experience
9.4.3 Accessibility and ease of use
9.5 Test results and discussion

## 10. Results and Discussion
10.1 System performance summary
10.2 Security and reliability assessment
10.3 Comparison with existing systems
10.4 Limitations and challenges
10.5 Lessons learned

## 11. Conclusion and Future Work
11.1 Conclusion
11.2 Contributions
11.3 Recommendations
11.4 Future research directions

## References
- Journals, articles, books, and tools used
- DeepFace library and biometric research
- Face recognition and liveness detection papers
- Secure electronic voting literature

## Appendices
A. Glossary of terms
A.1 ArcFace
A.2 FaceNet
A.3 GhostFaceNet
A.4 SFace
A.5 VGG-Face
A.6 RetinaFace
A.7 MediaPipe Face Mesh
A.8 OpenCV
A.9 MTCNN
A.10 SSD
A.11 Cosine similarity
A.12 Euclidean distance
A.13 Liveness detection
A.14 Anti-spoofing
A.15 Deepfake detection
A.16 JWT
A.17 AES/RSA
A.18 MySQL

B. System diagrams and architecture charts
C. API endpoints and payload examples
D. Database schema details
E. Deployment commands and environment configuration
F. Sample test cases and results
