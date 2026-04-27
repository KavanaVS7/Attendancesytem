// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AttendanceSystem {

    // ─── ROLES ─────────────────────────────────────────────
    address public hod;

    struct Student {
        string name;
        bool isRegistered;
        address parent;
        uint totalPresent;
        uint totalMarked;
    }

    mapping(address => Student) public students;
    address[] public studentList;

    // ─── SUBJECT STRUCT ────────────────────────────────────
    struct Subject {
        string name;
        address teacher;
        bool exists;
        uint sessionCount;
    }

    uint public subjectCount;
    mapping(uint => Subject) public subjects;

    // subjectId => list of students
    mapping(uint => address[]) public subjectStudents;

    // subjectId => student => enrolled?
    mapping(uint => mapping(address => bool)) public isEnrolled;

    // subjectId => sessionId => student => attendance
    mapping(uint => mapping(uint => mapping(address => int8))) public attendance;

    // subjectId => sessionId => student => marked?
    mapping(uint => mapping(uint => mapping(address => bool))) public isMarked;

    // ─── EVENTS ───────────────────────────────────────────
    event SubjectCreated(uint subjectId, string name, address teacher);
    event StudentRegistered(address student, string name);
    event Enrolled(uint subjectId, address student);
    event SessionCreated(uint subjectId, uint sessionId);
    event AttendanceMarked(uint subjectId, uint sessionId, address student, int8 status);

    // ─── MODIFIERS ────────────────────────────────────────
    modifier onlyHOD() {
        require(msg.sender == hod, "Only HOD");
        _;
    }

    modifier onlyTeacher(uint _subjectId) {
        require(subjects[_subjectId].teacher == msg.sender, "Not subject teacher");
        _;
    }

    modifier onlyStudent(address _student) {
        require(students[_student].isRegistered, "Not student");
        _;
    }

    modifier onlyParent(address _student) {
        require(students[_student].parent == msg.sender, "Not parent");
        _;
    }

    constructor() {
        hod = msg.sender;
    }

    // ─── HOD FUNCTIONS ────────────────────────────────────

    function registerStudent(address _student, string memory _name, address _parent)
        external onlyHOD
    {
        require(!students[_student].isRegistered, "Already registered");

        students[_student] = Student(_name, true, _parent, 0, 0);
        studentList.push(_student);

        emit StudentRegistered(_student, _name);
    }

    function createSubject(string memory _name, address _teacher)
        external onlyHOD returns (uint)
    {
        subjectCount++;

        subjects[subjectCount] = Subject({
            name: _name,
            teacher: _teacher,
            exists: true,
            sessionCount: 0
        });

        emit SubjectCreated(subjectCount, _name, _teacher);
        return subjectCount;
    }

    function enrollStudent(uint _subjectId, address _student)
        external onlyHOD onlyStudent(_student)
    {
        require(subjects[_subjectId].exists, "Invalid subject");
        require(!isEnrolled[_subjectId][_student], "Already enrolled");

        isEnrolled[_subjectId][_student] = true;
        subjectStudents[_subjectId].push(_student);

        emit Enrolled(_subjectId, _student);
    }

    // ─── TEACHER FUNCTIONS ────────────────────────────────

    function createSession(uint _subjectId)
        external onlyTeacher(_subjectId)
        returns (uint)
    {
        subjects[_subjectId].sessionCount++;
        uint sessionId = subjects[_subjectId].sessionCount;

        emit SessionCreated(_subjectId, sessionId);
        return sessionId;
    }

    function markAttendance(
        uint _subjectId,
        uint _sessionId,
        address _student,
        int8 _status
    )
        external
        onlyTeacher(_subjectId)
    {
        require(_sessionId > 0 && _sessionId <= subjects[_subjectId].sessionCount, "Invalid session");
        require(isEnrolled[_subjectId][_student], "Not enrolled");
        require(_status == 0 || _status == 1, "Invalid status");
        require(!isMarked[_subjectId][_sessionId][_student], "Already marked");

        isMarked[_subjectId][_sessionId][_student] = true;
        attendance[_subjectId][_sessionId][_student] = _status;

        students[_student].totalMarked++;

        if (_status == 1) {
            students[_student].totalPresent++;
        }

        emit AttendanceMarked(_subjectId, _sessionId, _student, _status);
    }

    // ─── VIEW FUNCTIONS ───────────────────────────────────

    function getMyAttendance() external view returns (uint) {
        Student memory s = students[msg.sender];
        require(s.isRegistered, "Not student");

        if (s.totalMarked == 0) return 0;
        return (s.totalPresent * 100) / s.totalMarked;
    }

    function getChildAttendance(address _student)
        external view onlyParent(_student)
        returns (uint)
    {
        Student memory s = students[_student];

        if (s.totalMarked == 0) return 0;
        return (s.totalPresent * 100) / s.totalMarked;
    }

    function getAttendanceStatus(
        uint _subjectId,
        uint _sessionId,
        address _student
    )
        external view returns (int8)
    {
        if (!isMarked[_subjectId][_sessionId][_student]) {
            return -1;
        }
        return attendance[_subjectId][_sessionId][_student];
    }

    function getSubjectStudents(uint _subjectId)
        external view returns (address[] memory)
    {
        return subjectStudents[_subjectId];
    }
}