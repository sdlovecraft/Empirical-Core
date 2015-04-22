"use strict";
$(function () {
	var ele = $('#activity-planner');
	if (ele.length > 0) {
		React.render(React.createElement(EC.LessonPlanner), ele[0]);
	}
});

EC.LessonPlanner = React.createClass({

	getInitialState: function () {
		return {
			tab: 'manageUnits',
			isInEditIndividualUnitMode: false,
			individualUnitToEdit: null
		}
	},

	getUnitNameForEditMode: function () {
		if (this.state.isInEditIndividualUnitMode) {
			return this.state.individualUnitToEdit.unit.name;
		} else {
			return null;
		}
	},

	getSelectedActivitiesForEditMode: function () {
		if (this.state.isInEditIndividualUnitMode) {
			return _.pluck(this.state.individualUnitToEdit.classroom_activities, 'activity');
		} else {
			return [];
		}
	},

	getDueDatesForEditMode: function () {
		var dueDates = {};
		var formattedDueDates = {};
		if (this.state.isInEditIndividualUnitMode) {
			_.each(this.state.individualUnitToEdit.classroom_activities, function (ca) {
				dueDates[ca.activity.id] = ca.due_date;
				formattedDueDates[ca.activity.id] = ca.formatted_due_date;
			});
		}
		return {dueDates: dueDates, formattedDueDates: formattedDueDates};
	},

	getSelectedClassroomsForEditMode: function () {
		if (this.state.isInEditIndividualUnitMode) {
			return _.map(this.state.individualUnitToEdit.classroom_activities, function (ca) {
				var x1 = {classroom_id: ca.classroom_id, assigned_student_ids: ca.assigned_student_ids};
				return x1;
			});
		} else {
			return [];
		}

	},

	getUnitIdForEditMode: function () {
		if (this.state.isInEditIndividualUnitMode) {
			return this.state.individualUnitToEdit.unit.id;
		} else {
			return null;
		}
	},

	toggleTab: function (tab) {
		this.setState({tab: tab, isInEditIndividualUnitMode: false, individualUnitToEdit: null});
	},

	editIndividualUnit: function (unit) {
		this.setState({tab: 'createUnit', isInEditIndividualUnitMode: true, individualUnitToEdit: unit});
	},

	render: function () {
		var tabSpecificComponents;
		if (this.state.tab == 'createUnit') {
			tabSpecificComponents = <EC.CreateUnit isInEditMode={this.state.isInEditIndividualUnitMode}
																						 unitName={this.getUnitNameForEditMode()}
																						 unitId={this.getUnitIdForEditMode()}
																						 selectedClassrooms={this.getSelectedClassroomsForEditMode()}
																						 selectedActivities={this.getSelectedActivitiesForEditMode()}
																						 dueDates={this.getDueDatesForEditMode().dueDates}
																						 formattedDueDates={this.getDueDatesForEditMode().formattedDueDates}
																						 toggleTab={this.toggleTab} />;
		} else {
			tabSpecificComponents = <EC.ManageUnits editIndividualUnit={this.editIndividualUnit}
																							toggleTab={this.toggleTab} />;
		}
		return (
			<span>
				<EC.UnitTabs tab={this.state.tab} isInEditIndividualUnitMode={this.state.isInEditIndividualUnitMode} toggleTab={this.toggleTab}/>
				<div id="lesson_planner" >
					{tabSpecificComponents}
				</div>
			</span>
		);
	}
});