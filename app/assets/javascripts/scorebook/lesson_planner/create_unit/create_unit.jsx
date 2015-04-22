"use strict";
EC.CreateUnit = React.createClass({

	getInitialState: function () {
		return {
			unitName: this.props.unitName,
			stage: 1, // stage 1 is selecting activities, stage 2 is selecting students and dates
			selectedActivities : this.props.selectedActivities,
			selectedClassrooms: [],
			classrooms: [],
			dueDates: this.props.dueDates,
			formattedDueDates: this.props.formattedDueDates
		}
	},

	assignActivityDueDate: function(activity, dueDate) {
		var dueDates = this.state.dueDates;
		dueDates[activity.id] = dueDate;
		this.setState({dueDates: dueDates});
	},

	toggleActivitySelection: function (true_or_false, activity) {
		var selectedActivities = this.state.selectedActivities;
		var dueDates = this.state.dueDates;
		if (true_or_false == true) {
			selectedActivities.push(activity);
		} else {
			selectedActivities = _.reject(selectedActivities, activity);
			delete dueDates[activity.id];
		}
		this.setState({selectedActivities: selectedActivities, dueDates: dueDates});
	},

	toggleClassroomSelection: function(classroom, flag) {
		var classrooms = this.state.classrooms;
		var updated = _.map(classrooms, function (c) {
			if (c.classroom.id == classroom.id) {
				if (c.students) {
					var selected = _.where(c.students, {isSelected: true});
					if (selected.length == c.students.length) {
						var updatedStudents = _.map(c.students, function (s) {
							s.isSelected = false;
							return s;
						});
					} else {
						var updatedStudents = _.map(c.students, function (s) {
							s.isSelected = true;
							return s;
						});
					}
					c.students = updatedStudents;
				}
			}
			return c;
		});
		this.setState({classrooms: updated});
	},

	toggleStudentSelection: function(student, classroom, flag) {
		var updated = _.map(this.state.classrooms, function (c) {
			if (c.classroom.id == classroom.id) {
				if (c.students) {
					var updated_students = _.map(c.students, function (s) {
						if (s.id == student.id) {
							s.isSelected = flag;
						}
						return s;
					});
					c.students = updated_students;
				}
			}
			return c;
		});
		this.setState({classrooms: updated});
	},

	updateUnitName: function (unitName) {
		this.setState({unitName: unitName});
	},

	clickContinue: function () {
		this.fetchClassrooms();
		this.setState({stage: 2});
	},

	fetchClassrooms: function() {
    var that = this;
    $.ajax({
      url: '/teachers/classrooms/retrieve_classrooms_for_assigning_activities',
      context: this,
      success: function (data) {
        if (that.props.isInEditMode) {
        	_.each(data.classrooms_and_their_students, function (c) {
        		var extant = _.findWhere(that.props.selectedClassrooms, {id: c.id});
        		if (extant != undefined) {
        			if (extant.assigned_student_ids.length == 0) {
        				_.each(c.students, function (s) {
        					s.isSelected = true;
        				});
        			} else {
        				_.each(extant.assigned_student_ids, function (id) {
        					var relevantParty = _.findWhere(c.students, {id: id});
        					relevantParty.isSelected = true;
        				});
        			}
        		}
        	});
        }
        that.setState({classrooms: data.classrooms_and_their_students});
      }
    });
  },

	finish: function() {
		var method, url;
		if (this.props.isInEditMode == true) {
			method = 'PUT';
			url = '/teachers/units/' + this.props.unitId;
		} else {
			method = 'POST';
			url = '/teachers/units';
		}
		$.ajax({
			type: method,
			url: url,
			contentType: 'application/json',
			dataType: 'json',
			data: this.formatCreateRequestData(),
			success: this.onCreateSuccess,
		});
	},

	formatCreateRequestData: function() {
		var classroomPostData = _.select(this.state.classrooms, function (c) {
			var selectedStudents;
			if (!c.students) {
				selectedStudents = [];
			} else {
				selectedStudents = _.where(c.students, {isSelected: true});
			}
			return (selectedStudents.length > 0);
		});

		classroomPostData = _.map(classroomPostData, function (c) {
			var selectedStudentIds, allStudents;
			var selectedStudents = _.where(c.students, {isSelected: true});
			if (selectedStudents.length == c.students.length) {
				selectedStudentIds = [];
				allStudents = true;
			} else {
				selectedStudentIds = _.map(selectedStudents, function (s) {return s.id});
				allStudents = false;
			}
			return {id: c.classroom.id, all_students: allStudents,  student_ids: selectedStudentIds};
		});

		var activityPostData = _.map(this.state.dueDates, function(key, value) {
			return {
				id: parseInt(value),
				due_date: key
			}
		});
		var x = {
			unit: {
				name: this.state.unitName,
				classrooms: classroomPostData,
				activities: activityPostData
			}
		};
		var stringified = JSON.stringify(x);
		return stringified;
	},

	onCreateSuccess: function(response) {
		this.props.toggleTab('manageUnits');
	},

	isUnitNameSelected: function () {
		return ((this.state.unitName != null) && (this.state.unitName != ''));
	},

	determineIfEnoughInputProvidedForStage1: function () {
		var a = this.isUnitNameSelected();
		var b = (this.state.selectedActivities.length > 0);
		return (a && b);
	},

	areAnyStudentsSelected: function () {
		var x = _.select(this.state.classrooms, function (c) {
			var y = _.where(c.students, {isSelected: true});
			return (y.length > 0);
		});
		return (x.length > 0);
	},

	areAllDueDatesProvided: function () {
		return (Object.keys(this.state.dueDates).length == this.state.selectedActivities.length);
	},

	determineStage1ErrorMessage: function () {
		var a = this.isUnitNameSelected();
		var b = (this.state.selectedActivities.length > 0);
		var msg;
		if (!a) {
			if (!b) {
				msg = "Please provide a unit name and select activities";
			} else {
				msg = "Please provide a unit name";
			}
		} else if (!b) {
			msg = "Please select activities";
		} else {
			msg = null;
		}
		return msg;
	},

	determineStage2ErrorMessage: function () {
		var a = this.areAnyStudentsSelected();
		var b = this.areAllDueDatesProvided();
		var msg;
		if (!a) {
			if (!b) {
				msg = "Please select students and due dates";
			} else {
				msg = "Please select students";
			}
		} else if (!b) {
			msg = "Please select due dates";
		} else {
			msg = null;
		}
		return msg;
	},

	render: function () {
		var stageSpecificComponents;

		if (this.state.stage === 1) {
			stageSpecificComponents = <EC.Stage1 toggleActivitySelection={this.toggleActivitySelection}
								 unitName = {this.state.unitName}
								 updateUnitName={this.updateUnitName}
								 selectedActivities={this.state.selectedActivities}
								 isEnoughInputProvidedForStage1={this.determineIfEnoughInputProvidedForStage1()}
								 errorMessage={this.determineStage1ErrorMessage()}
								 clickContinue={this.clickContinue} />;
		} else {
			stageSpecificComponents = <EC.Stage2 isInEditMode={this.props.isInEditMode}
																					 selectedActivities={this.state.selectedActivities}
																					 classrooms={this.state.classrooms}
																					 toggleActivitySelection={this.toggleActivitySelection}
																					 toggleClassroomSelection={this.toggleClassroomSelection}
																					 toggleStudentSelection={this.toggleStudentSelection}
																					 finish={this.finish}
																					 unitName={this.state.unitName}
																					 assignActivityDueDate={this.assignActivityDueDate}
																					 areAnyStudentsSelected={this.areAnyStudentsSelected()}
																					 areAllDueDatesProvided={this.areAllDueDatesProvided()}
																					 formattedDueDates={this.state.formattedDueDates}
																					 errorMessage={this.determineStage2ErrorMessage()}/>;
		}
		return (
			<span>
				<EC.ProgressBar stage={this.state.stage}/>
				<div className='container lesson_planner_main'>
					{stageSpecificComponents}
				</div>
			</span>

		);
	}
});