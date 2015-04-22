"use strict";
EC.UnitTabs = React.createClass({

	selectCreateUnit: function () {
		if (this.props.tab == 'manageUnits') {
			this.props.toggleTab('createUnit');
		}
	},

	selectManageUnits: function () {
		if (this.props.tab != 'manageUnits') {
			this.props.toggleTab('manageUnits');
		}
	},

	determineCreateAUnitTabText: function () {
		if (this.props.isInEditIndividualUnitMode == true) {
			return "Edit a Unit";
		} else {
			return "Create a Unit";
		}
	},

	render: function () {
		var createUnitClass, manageUnitsClass;
		if (this.props.tab == 'createUnit') {
			createUnitClass = 'active';
			manageUnitsClass = '';
		} else {
			createUnitClass = '';
			manageUnitsClass = 'active';
		}

		return (
			<div className="unit-tabs tab-subnavigation-wrapper">
				<div className="container">
					<ul>
						<li onClick={this.selectManageUnits}><a className={manageUnitsClass}>My Units</a></li>
						<li onClick={this.selectCreateUnit}><a className={createUnitClass}>{this.determineCreateAUnitTabText()}</a></li>
					</ul>
				</div>
			</div>
		);
	}
});