// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

contract SchoolManagement {
	address public headmaster;
	mapping(address => bool) private existInStudents;
	mapping(address => bool) private existInTeachers;
    mapping(string => bool) private existInClasses;
	mapping(string => bool) private existInSubjects;
	
	enum PersonStatus{
		Active,
		Inactive
	}
	
	struct Teacher{
		address id;
		string name; 
		PersonStatus status;
	}
	
	struct Class{
		string name; 				// A class name could be fruits, e.g. orange, mango, grape, etc.; assumtion: no duplicate of class name.
		address homeroom_teacher; 	// A homeroom teacher must be an active teacher.
	}
	
	struct Subject{
		string name;			// Subject name, e.g. math, physics, history, sociology, anthropology.
		address[] teachers;	    // A subject can be taught by more than one teacher.
	}
		
	struct Student{
		address id;
		string name;
		string class_name;
		PersonStatus status;
	}
	
	struct Report{
		address student_id;
		string subject_name;
		uint score;
	}

	Teacher[] teachers;	
	Class[] classes;
	Subject[] subjects;
	Student[] students;
	Report[] reports;
	
	constructor(){
		headmaster = msg.sender; // initially the person who deployed the contract will be the headmaster
	}
	
	modifier onlyHeadmaster(){
		require(msg.sender == headmaster, "Only the headmaster can perform this task.");
		_;
	}
	
	modifier onlyActiveTeacher(){
		require(teachers[uint(uint160(msg.sender))].status == PersonStatus.Active, "Only an active teacher can perform this task.");
		_;
	}
	
	// The current headmaster can appoint a new headmaster as long as this new person is not a current student.
	function changeHeadmaster(address _address) public onlyHeadmaster{
		require(existInStudents[_address] == false, "A student cannot be appointed as a headmaster.");
		require(_address != headmaster, "A new headmaster must be different to the existing one.");
	
		headmaster = _address;	
	}

	// Everyone can register a new teacher.
	function registerNewTeacher(address _address, string memory _name) public{		
		require(existInTeachers[_address] == false, "This person has been registered as a teacher.");
		require(existInStudents[_address] == false, "A student cannot be registered as a teacher.");
		
		if (msg.sender == headmaster){
			teachers.push(Teacher(_address, _name, PersonStatus.Active)); 	// A headmaster can register a new teacher with active status.
		}
		else {
			teachers.push(Teacher(_address, _name, PersonStatus.Inactive)); // Everyone can register a new teacher with inactive status.
		}
		
		existInTeachers[_address] = true;
	}

    // Get a teacher index
    function getTeacherIndex(address _teacherid) private view returns(uint){
		for (uint i = 0; i < teachers.length; i++) {
            
            if (teachers[i].id == _teacherid) { return i; }
        } 
        revert("Teacher not found.");      
    }
	
	// A headmaster can activate a teacher.
	function activateTeacher(address _address) public onlyHeadmaster{
		require(existInTeachers[_address] == true, "The person has not been registered as a teacher.");
		teachers[getTeacherIndex(_address)].status = PersonStatus.Active;
	}
	
	// A headmaster can deactivate anyone. Teachers or students can only deactivate themselves.
	function deactivatePerson(address _address) public returns(string memory){
		require(existInTeachers[_address] == true || existInStudents[_address], "The person must be a registered teacher or student.");
		require((msg.sender == headmaster) || (msg.sender == _address), "If you are not a headmaster, you can only deactivate yourself.");
		
		if (existInTeachers[_address] == true){
			teachers[getTeacherIndex(_address)].status = PersonStatus.Inactive;
			return "The teacher is now deactivated or resigned.";
		}
		else{
			students[getStudentIndex(_address)].status = PersonStatus.Inactive;
			return "The student is now deactivated or resigned.";
		}
	}
		
	// A headmaster can register a new class with an active teacher as a homeroom teacher.
	function registerNewClass(string memory _classname, address _teacherid) public onlyHeadmaster{
		require(existInClasses[_classname] == false, "This class name has been registered.");
		require((existInTeachers[_teacherid] == true), "The homeroom teacher must be registered first.");
		require(teachers[getTeacherIndex(_teacherid)].status == PersonStatus.Active, "The homeroom teacher must be activated first.");
		
		classes.push(Class(_classname, _teacherid));
		existInClasses[_classname] = true;
	}
	
	// A headmaster can change a homeroom teacher.
	function changeHomeroomTeacher(string memory _classname, address _teacherid) public onlyHeadmaster{
		require(existInClasses[_classname] == true, "The class name must be registered.");
		require(existInTeachers[_teacherid] == true, "A new homeroom teacher must be registered as a teacher.");
		require(teachers[getTeacherIndex(_teacherid)].status == PersonStatus.Active, "A new homeroom teacher must be an active teacher.");
        require(classes[getClassIndex(_classname)].homeroom_teacher == _teacherid, "A new homeroom teacher must be different to the existing one.");

		classes[getClassIndex(_classname)].homeroom_teacher = _teacherid;
	}

    // Get a class index
    function getClassIndex(string memory _classname) private view returns(uint){
		for (uint i = 0; i < classes.length; i++) {

            // This script is commented because direct string comparison is not possible in Solidity.
			//if (classes[i].name == _classname) { return i; }
            
            if (keccak256(bytes(classes[i].name)) == keccak256(bytes(_classname))) { return i; }
        } 
        revert("Class not found.");      
    }
	
	// A headmaster can register a new subject with list of registered teachers (regardless of teacher's status)
	function registerNewSubject(string memory _subjectname, address[] memory _addresses) public onlyHeadmaster{ 
		require(existInSubjects[_subjectname] == false, "The subject has been registered.");
		require(areRegisteredTeachers(_addresses) == true, "Teachers must be registered before can be assigned to a subject.");
		
		subjects.push(Subject(_subjectname, _addresses));
		existInSubjects[_subjectname] = true;
	}
	
	function areRegisteredTeachers(address[] memory _addresses) private view returns(bool){
		for (uint i = 0; i < _addresses.length; i++) {
			if (existInTeachers[_addresses[i]] == false) { return false; }
        }
		return true;
	}
	
	// A headmaster can update an existing subject with a new list of registered teachers (regardless of teacher's status).
	function updateSubject(string calldata _subjectname, address[] memory _addresses) public onlyHeadmaster{ 
        require(existInSubjects[_subjectname] == true, "The subject must be registered.");   
        require(areRegisteredTeachers(_addresses) == true, "Teachers must be registered before can be assigned to a subject.");

		subjects[getSubjectIndex(_subjectname)].teachers = _addresses;
	}

    // Get a subject index
    function getSubjectIndex(string memory _subjectname) private view returns(uint){
		for (uint i = 0; i < subjects.length; i++) {

            // This script is commented because direct string comparison is not possible in Solidity.
			//if (subjects[i].name == _subjectsname) { return i; }
            
            if (keccak256(bytes(subjects[i].name)) == keccak256(bytes(_subjectname))) { return i; }
        } 
        revert("Subject not found.");      
    }
	
	// Everyone can register a new student	
	function registerNewStudent(address _address, string memory _name, string calldata _classname) public{		
		require(existInStudents[_address] == false, "This person has been registered as a student.");
		require(existInTeachers[_address] == false, "A teacher cannot be registered as a student.");
		
        // These scripts are commented because direct string comparison is not possible in Solidity.
        //require(_name != "", "A student name cannot be empty.");
        //require((_classname == "") || existInClasses[_classname], "A class name can be left empty or must be a registered class name.");
		
        require(bytes(_name).length != 0, "A student name cannot be empty.");
        require((bytes(_classname).length == 0) || existInClasses[_classname], "A class name can be left empty or must be a registered class name.");

		if (msg.sender == headmaster){
			students.push(Student(_address, _name, _classname,  PersonStatus.Active)); 	// A headmaster can register a new student with active status.
		}
		else {
			students.push(Student(_address, _name, _classname, PersonStatus.Inactive)); // Everyone can register a new student with inactive status.
		}
		
		existInStudents[_address] = true;
	}
	
	// Get a student index
    function getStudentIndex(address _studentid) private view returns(uint){
		for (uint i = 0; i < students.length; i++) {

            // This script is commented because direct string comparison is not possible in Solidity.
			//if (student[i].name == _studentname) { return i; }
            
            if (students[i].id == _studentid) { return i; }
        } 
        revert("Student not found.");      
    }
	
	// A headmaster can update student information.
	function updateStudent(address _address, string memory _name, string memory _classname) public onlyHeadmaster{		
		require(existInStudents[_address] == true, "This person must be registered as a student.");
		require((keccak256(bytes(_classname)) == keccak256(bytes(""))) || existInClasses[_classname], "A class name can be left empty or must be a registered class name.");
		
		// if the headmaster does not input the student's name, do not change the student's name.
		if (keccak256(bytes(_name)) != keccak256(bytes(""))) { students[getStudentIndex(_address)].name = _name; }
		
		// if the headmaster does not input the student's class name, do not change the student's class name.
		if (keccak256(bytes(_classname)) != keccak256(bytes(""))) { students[getStudentIndex(_address)].class_name = _classname; }
	}	
	
	// A headmaster can activate a student.
	function activateStudent(address _address) public onlyHeadmaster{
		require(existInStudents[_address] == true, "The person has not been registered as a student.");
		students[getStudentIndex(_address)].status = PersonStatus.Active;
	}

	// An active teacher can set a student's report on subjects that he/she is teaching.
	function setReport(address _studentid, string memory _subjectname, uint _score) public onlyActiveTeacher{
		require(existInStudents[_studentid] == true, "The student does not exist.");
		require(existInSubjects[_subjectname] == true, "The subject does not exist.");
		require((_score >= 0) && (_score <= 100), "The score must be between 0 and 100.");
		require(validSubjectTeacher(_subjectname, msg.sender), "The subject and teacher combination is invalid. The teacher does not teach the mentioned subject.");
		
		reports.push(Report(_studentid, _subjectname, _score));
	}
	
	// This function validates whether a subject name is taught by a teacher.
	function validSubjectTeacher(string memory _subjectname, address _teacherid) private view returns(bool){
		address[] memory subject_teachers = subjects[getSubjectIndex(_subjectname)].teachers;
		
		for (uint i = 0; i < subject_teachers.length; i++) {
            if (subject_teachers[i] == _teacherid) { return true; }
        } 
        return false;
	}

	// To simplify the testing, everyone can show students.
	function showTeachers() public view returns(Teacher[] memory){
		return teachers;
	}
	
	// To simplify the testing, everyone can show classes.
	function showClasses() public view returns(Class[] memory){
		return classes;
	}

	// To simplify the testing, everyone can show subjects.
	function showSubjects() public view returns(Subject[] memory){
		return subjects;
	}
	
	// To simplify the testing, everyone can show students.
	function showStudents() public view returns(Student[] memory){
		return students;
	}
	
	// To simplify the testing, everyone can show reports.
	function showReports() public view returns(Report[] memory){
		return reports;
	}
}