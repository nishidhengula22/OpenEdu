// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title OpenEdu
 * @dev A decentralized education platform for course management and certification
 * @author OpenEdu Team
 */
contract OpenEdu {
    
    // State variables
    address public owner;
    uint256 public courseCount;
    uint256 public studentCount;
    
    // Structures
    struct Course {
        uint256 id;
        string title;
        string description;
        address instructor;
        uint256 price;
        uint256 duration; // in days
        bool isActive;
        uint256 enrolledStudents;
        mapping(address => bool) enrollments;
        mapping(address => bool) completions;
    }
    
    struct Student {
        address studentAddress;
        string name;
        uint256[] enrolledCourses;
        uint256[] completedCourses;
        uint256 totalCoursesCompleted;
    }
    
    struct Certificate {
        uint256 courseId;
        address student;
        uint256 issueDate;
        string certificateHash;
        bool isValid;
    }
    
    // Mappings
    mapping(uint256 => Course) public courses;
    mapping(address => Student) public students;
    mapping(address => bool) public registeredStudents;
    mapping(uint256 => Certificate) public certificates;
    mapping(address => mapping(uint256 => uint256)) public studentCertificates;
    
    // Events
    event CourseCreated(uint256 indexed courseId, string title, address indexed instructor, uint256 price);
    event StudentEnrolled(address indexed student, uint256 indexed courseId, uint256 timestamp);
    event CourseCompleted(address indexed student, uint256 indexed courseId, uint256 certificateId);
    event StudentRegistered(address indexed student, string name);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier onlyRegisteredStudent() {
        require(registeredStudents[msg.sender], "Student must be registered");
        _;
    }
    
    modifier courseExists(uint256 _courseId) {
        require(_courseId > 0 && _courseId <= courseCount, "Course does not exist");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        courseCount = 0;
        studentCount = 0;
    }
    
    /**
     * @dev Core Function 1: Create and manage courses
     * @param _title Course title
     * @param _description Course description
     * @param _price Course price in wei
     * @param _duration Course duration in days
     */
    function createCourse(
        string memory _title,
        string memory _description,
        uint256 _price,
        uint256 _duration
    ) public returns (uint256) {
        require(bytes(_title).length > 0, "Course title cannot be empty");
        require(_duration > 0, "Course duration must be greater than 0");
        
        courseCount++;
        Course storage newCourse = courses[courseCount];
        newCourse.id = courseCount;
        newCourse.title = _title;
        newCourse.description = _description;
        newCourse.instructor = msg.sender;
        newCourse.price = _price;
        newCourse.duration = _duration;
        newCourse.isActive = true;
        newCourse.enrolledStudents = 0;
        
        emit CourseCreated(courseCount, _title, msg.sender, _price);
        return courseCount;
    }
    
    /**
     * @dev Core Function 2: Student enrollment and course management
     * @param _courseId ID of the course to enroll in
     */
    function enrollInCourse(uint256 _courseId) 
        public 
        payable 
        courseExists(_courseId) 
        onlyRegisteredStudent 
    {
        Course storage course = courses[_courseId];
        require(course.isActive, "Course is not active");
        require(!course.enrollments[msg.sender], "Already enrolled in this course");
        require(msg.value >= course.price, "Insufficient payment");
        
        // Process enrollment
        course.enrollments[msg.sender] = true;
        course.enrolledStudents++;
        
        // Update student record
        students[msg.sender].enrolledCourses.push(_courseId);
        
        // Refund excess payment
        if (msg.value > course.price) {
            payable(msg.sender).transfer(msg.value - course.price);
        }
        
        // Transfer payment to instructor
        if (course.price > 0) {
            payable(course.instructor).transfer(course.price);
        }
        
        emit StudentEnrolled(msg.sender, _courseId, block.timestamp);
    }
    
    /**
     * @dev Core Function 3: Issue certificates and manage completions
     * @param _courseId ID of the completed course
     * @param _student Address of the student
     * @param _certificateHash IPFS hash of the certificate
     */
    function issueCertificate(
        uint256 _courseId,
        address _student,
        string memory _certificateHash
    ) public courseExists(_courseId) returns (uint256) {
        Course storage course = courses[_courseId];
        require(
            msg.sender == course.instructor || msg.sender == owner,
            "Only instructor or owner can issue certificates"
        );
        require(course.enrollments[_student], "Student not enrolled in this course");
        require(!course.completions[_student], "Certificate already issued for this student");
        require(bytes(_certificateHash).length > 0, "Certificate hash cannot be empty");
        
        // Mark course as completed
        course.completions[_student] = true;
        
        // Create certificate
        uint256 certificateId = uint256(keccak256(abi.encodePacked(_courseId, _student, block.timestamp)));
        certificates[certificateId] = Certificate({
            courseId: _courseId,
            student: _student,
            issueDate: block.timestamp,
            certificateHash: _certificateHash,
            isValid: true
        });
        
        // Update student record
        students[_student].completedCourses.push(_courseId);
        students[_student].totalCoursesCompleted++;
        studentCertificates[_student][_courseId] = certificateId;
        
        emit CourseCompleted(_student, _courseId, certificateId);
        return certificateId;
    }
    
    // Additional helper functions
    function registerStudent(string memory _name) public {
        require(!registeredStudents[msg.sender], "Student already registered");
        require(bytes(_name).length > 0, "Name cannot be empty");
        
        registeredStudents[msg.sender] = true;
        students[msg.sender].studentAddress = msg.sender;
        students[msg.sender].name = _name;
        students[msg.sender].totalCoursesCompleted = 0;
        studentCount++;
        
        emit StudentRegistered(msg.sender, _name);
    }
    
    function getCourseInfo(uint256 _courseId) 
        public 
        view 
        courseExists(_courseId) 
        returns (
            string memory title,
            string memory description,
            address instructor,
            uint256 price,
            uint256 duration,
            bool isActive,
            uint256 enrolledStudents
        ) 
    {
        Course storage course = courses[_courseId];
        return (
            course.title,
            course.description,
            course.instructor,
            course.price,
            course.duration,
            course.isActive,
            course.enrolledStudents
        );
    }
    
    function isEnrolled(address _student, uint256 _courseId) 
        public 
        view 
        courseExists(_courseId) 
        returns (bool) 
    {
        return courses[_courseId].enrollments[_student];
    }
    
    function hasCompleted(address _student, uint256 _courseId) 
        public 
        view 
        courseExists(_courseId) 
        returns (bool) 
    {
        return courses[_courseId].completions[_student];
    }
    
    function verifyCertificate(uint256 _certificateId) 
        public 
        view 
        returns (bool isValid, uint256 courseId, address student, uint256 issueDate) 
    {
        Certificate storage cert = certificates[_certificateId];
        return (cert.isValid, cert.courseId, cert.student, cert.issueDate);
    }
    
    function getStudentCourses(address _student) 
        public 
        view 
        returns (uint256[] memory enrolled, uint256[] memory completed) 
    {
        require(registeredStudents[_student], "Student not registered");
        Student storage student = students[_student];
        return (student.enrolledCourses, student.completedCourses);
    }
    
    // Owner functions
    function toggleCourseStatus(uint256 _courseId) 
        public 
        onlyOwner 
        courseExists(_courseId) 
    {
        courses[_courseId].isActive = !courses[_courseId].isActive;
    }
    
    function withdrawFunds() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
