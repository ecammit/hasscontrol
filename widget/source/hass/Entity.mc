
using Toybox.System;
using Utils;

module Hass {
  class Entity {
    // Persisted form: this many flat slots per entity, laid end to end in one
    // Array - see writeToStorage()/createFromStorage(). Entities used to be
    // stored as one seven-key Dictionary each; serialising 13 of those blew
    // past the free-heap floor and crashed inside App.Storage.setValue() on
    // Instinct 2X. A Dictionary carries its hash table and per-entry objects,
    // a flat Array is one allocation of plain slots.
    //
    // `ext` is deliberately not persisted: external (settings-defined)
    // entities are never written, so it is always false on read.
    //
    // select's `options` (a String Array) and input_number/number's
    // min/max/step are dropped from the persisted form on 64 KB widget
    // devices (:lowmem, see monkey.jungle) - not because persisting them was
    // measured to cause a problem, but to keep this array's footprint at
    // its pre-existing size on a tier that's already tight on static
    // footprint (see Utils.debugLog() and friends). Those devices always
    // start select/input_number from a live refresh rather than the
    // offline cache; they still work the same otherwise.
    (:fullmem)
    static const STORED_FIELDS = 10;

    (:lowmem)
    static const STORED_FIELDS = 6;

    // Appends this entity at `offset` and returns the next free offset.
    (:fullmem)
    function writeToStorage(target, offset) {
      target[offset]     = _mId;
      target[offset + 1] = _mName;
      target[offset + 2] = Entity.stateToString(_mState);
      target[offset + 3] = _mSensorClass;
      target[offset + 4] = _mIcon;
      target[offset + 5] = _mDeviceClass;
      target[offset + 6] = _mOptions;
      target[offset + 7] = _mMin;
      target[offset + 8] = _mMax;
      target[offset + 9] = _mStep;

      return offset + Entity.STORED_FIELDS;
    }

    (:lowmem)
    function writeToStorage(target, offset) {
      target[offset]     = _mId;
      target[offset + 1] = _mName;
      target[offset + 2] = Entity.stateToString(_mState);
      target[offset + 3] = _mSensorClass;
      target[offset + 4] = _mIcon;
      target[offset + 5] = _mDeviceClass;

      return offset + Entity.STORED_FIELDS;
    }

    (:fullmem)
    static function createFromStorage(stored, offset) {
      var id = stored[offset];

      if (id == null) {
        return null;
      }

      var name = stored[offset + 1];

      return new Entity({
        :id => id,
        :name => name != null ? name : id,
        :state => stored[offset + 2],
        :sensorClass => stored[offset + 3],
        :icon => stored[offset + 4],
        :deviceClass => stored[offset + 5],
        :options => stored[offset + 6],
        :min => stored[offset + 7],
        :max => stored[offset + 8],
        :step => stored[offset + 9]
      });
    }

    (:lowmem)
    static function createFromStorage(stored, offset) {
      var id = stored[offset];

      if (id == null) {
        return null;
      }

      var name = stored[offset + 1];

      return new Entity({
        :id => id,
        :name => name != null ? name : id,
        :state => stored[offset + 2],
        :sensorClass => stored[offset + 3],
        :icon => stored[offset + 4],
        :deviceClass => stored[offset + 5]
      });
    }

    // Reads the pre-2.0.4 storage format. Only used by the one-time migration
    // in Hass.loadStoredEntities().
    static function createFromDict(dict) {
      // Null safety: check for null or invalid dictionary
      if (dict == null) {
        Utils.debugLog("Entity.createFromDict: dict is null, skipping", null, null);
        return null;
      }
      if (dict["id"] == null) {
        Utils.debugLog("Entity.createFromDict: dict[id] is null, skipping", null, null);
        return null;
      }
      return new Entity({
        :id => dict["id"],
        :name => dict["name"] != null ? dict["name"] : dict["id"],
        :state => dict["state"],
        :ext => dict["ext"],
        :sensorClass => dict["sensorClass"],
        :icon => dict["icon"],
        :deviceClass => dict["deviceClass"]
      });
    }

    static function stringToState(stateInText) {
      if (stateInText == null) {
        return null;
      }
      if (HASS_STATE_ON.equals(stateInText)) {
        return STATE_ON;
      }
      if (HASS_STATE_OFF.equals(stateInText)) {
        return STATE_OFF;
      }
      if (HASS_STATE_LOCKED.equals(stateInText)) {
        return STATE_LOCKED;
      }
      if (HASS_STATE_UNLOCKED.equals(stateInText)) {
        return STATE_UNLOCKED;
      }
      if (HASS_STATE_LOCKING.equals(stateInText)) {
        return STATE_LOCKING;
      }
      if (HASS_STATE_UNLOCKING.equals(stateInText)) {
        return STATE_UNLOCKING;
      }
      if (HASS_STATE_OPEN.equals(stateInText)) {
        return STATE_OPEN;
      }
      if (HASS_STATE_OPENING.equals(stateInText)) {
        return STATE_OPENING;
      }
      if (HASS_STATE_CLOSED.equals(stateInText)) {
        return STATE_CLOSED;
      }
      if (HASS_STATE_CLOSING.equals(stateInText)) {
        return STATE_CLOSING;
      }

      return STATE_UNKNOWN;
    }

    static function stateToString(state) {
      if (state == STATE_ON) {
        return HASS_STATE_ON;
      }
      if (state == STATE_OFF) {
        return HASS_STATE_OFF;
      }
      if (state == STATE_OPEN) {
        return HASS_STATE_OPEN;
      }
      if (state == STATE_OPENING) {
        return HASS_STATE_OPENING;
      }
      if (state == STATE_CLOSED) {
        return HASS_STATE_CLOSED;
      }
      if (state == STATE_CLOSING) {
        return HASS_STATE_CLOSING;
      }
      if (state == STATE_LOCKED) {
        return HASS_STATE_LOCKED;
      }
      if (state == STATE_UNLOCKED) {
        return HASS_STATE_UNLOCKED;
      }
      if (state == STATE_LOCKING) {
        return HASS_STATE_LOCKING;
      }
      if (state == STATE_UNLOCKING) {
        return HASS_STATE_UNLOCKING;
      }

      if (state == null) {
        return null;
      }

      return HASS_STATE_UNKNOWN;
    }

    hidden var _mId; // Home assistant id
    hidden var _mType; // Type of entity
    hidden var _mName; // Name
    hidden var _mState; // Current State
    hidden var _mExt; // Is this entity loaded from settings?
    hidden var _mSensorValue; // Custom state info text
    hidden var _mSensorClass; // Device class for sensor
    hidden var _mIcon; // Home Assistant `icon` attribute (e.g. "mdi:movie-open")
    hidden var _mDeviceClass; // Home Assistant `device_class` attribute (e.g. "battery")

    // select's `options` (a short string Array - a handful of a few chars
    // each, in practice) plus input_number/number's min/max/step/service
    // domain - kept on every tier so the lowmem in-place editor can use
    // them without a separate network round-trip per edit.
    hidden var _mOptions;
    hidden var _mMin;
    hidden var _mMax;
    hidden var _mStep;
    hidden var _mServiceDomain;

    function initialize(entity) {
      _mId = entity[:id];
      _mName = entity[:name];
      _mState = Entity.stringToState(entity[:state]);
      _mExt = entity[:ext] == true;
      _mSensorClass = entity[:sensorClass];
      _mIcon = entity[:icon];
      _mDeviceClass = entity[:deviceClass];
      _initExtendedFields(entity);

      // Null safety: prevent crash if _mId is null
      if (_mId == null) {
        Utils.debugLog("Entity.initialize: entity ID is null", null, null);
        _mType = TYPE_UNKNOWN;
        return;
      }

      if (_mId.find("scene.") != null) {
        _mType = TYPE_SCENE;
      } else if (_mId.find("light.") != null) {
        _mType = TYPE_LIGHT;
      } else if (_mId.find("switch.") != null) {
        _mType = TYPE_SWITCH;
      } else if (_mId.find("valve.") != null) {
        _mType = TYPE_VALVE;
      } else if (_mId.find("automation.") != null) {
        _mType = TYPE_AUTOMATION;
      } else if (_mId.find("script.") != null) {
        _mType = TYPE_SCRIPT;
      } else if (_mId.find("lock.") != null) {
        _mType = TYPE_LOCK;
      } else if (_mId.find("cover.") != null) {
        _mType = TYPE_COVER;
      } else if (_mId.find("fan.") != null) {
        _mType = TYPE_FAN;
      } else if (_mId.find("binary_sensor.") != null) {
        _mType = TYPE_BINARY_SENSOR;
      } else if (_mId.find("input_boolean.") != null) {
        _mType = TYPE_INPUT_BOOLEAN;
      } else if (_mId.find("input_button.") != null) {
        _mType = TYPE_INPUT_BUTTON;
      } else if (_mId.find("button.") != null) {
        _mType = TYPE_BUTTON;
      } else if (_mId.find("sensor.") != null) {
        _mType = TYPE_SENSOR;
      } else {
        _mType = detectExtendedType(_mId);
      }
    }

    // select/input_number/number are supported on every tier, though
    // fullmem and 64 KB widget devices (:lowmem, see monkey.jungle) present
    // them differently: fullmem uses the Menu2 option picker and the
    // InputNumberEditView screen; lowmem uses an in-place list editor (see
    // EntityListController's editing state and
    // EntityListDelegate.handleExtendedEntityTypes()) that's cheap enough
    // to fit that tier's budget instead.
    hidden function detectExtendedType(id) {
      // Checked before the plain "select." below, same reasoning as
      // input_number/number: "select." is a substring of "input_select.",
      // so checking the more specific input_ prefix first is what keeps
      // input_select.* entities from being misrouted to the "select"
      // domain's service (which HA accepts with a 200 but silently ignores
      // for an entity it doesn't own).
      if (id.find("input_select.") != null) {
        _mServiceDomain = "input_select";
        return TYPE_SELECT;
      }
      if (id.find("select.") != null) {
        _mServiceDomain = "select";
        return TYPE_SELECT;
      }
      if (id.find("input_number.") != null) {
        _mServiceDomain = "input_number";
        return TYPE_INPUT_NUMBER;
      }
      if (id.find("number.") != null) {
        _mServiceDomain = "number";
        return TYPE_INPUT_NUMBER;
      }
      return TYPE_UNKNOWN;
    }

    hidden function _initExtendedFields(entity) {
      _mOptions = entity[:options];
      _mMin = entity[:min];
      _mMax = entity[:max];
      _mStep = entity[:step];
    }

    function getId() {
      return _mId;
    }

    function getName() {
      if (_mState == STATE_SENSOR) {
        return _mName + "\n" + _mSensorValue;
      }
      else {
        return _mName;
      }
    }

    function setName(newName) {
      _mName = newName;
    }

    function getRawName() {
      return _mName;
    }

    function getType() {
      return _mType;
    }

    function setState(newState) {
      if (newState instanceof String) {
        if (_mType == TYPE_SENSOR || _mType == TYPE_SELECT || _mType == TYPE_INPUT_NUMBER) {
          _mState = STATE_SENSOR;
          _mSensorValue = newState;
        } else {
          _mState = Entity.stringToState(newState);
        }
        return;
      }

      if (
        newState != null
        && newState != STATE_ON
        && newState != STATE_OFF
        && newState != STATE_LOCKED
        && newState != STATE_UNLOCKED
        && newState != STATE_LOCKING
        && newState != STATE_UNLOCKING
        && newState != STATE_CLOSED
        && newState != STATE_CLOSING
        && newState != STATE_OPEN
        && newState != STATE_OPENING
        && newState != STATE_SENSOR
        && newState != STATE_UNKNOWN
      ) {
        throw new Toybox.Lang.InvalidValueException("Invalid entity state value");
      }

      _mState = newState;
    }

    function getState() {
      return _mState;
    }


    function getSensorValue() {
      return _mSensorValue;
    }

    function getSensorClass() {
      return _mSensorClass;
    }

    function setSensorClass(newSensorClass) {
      _mSensorClass = newSensorClass;
    }

    // Home Assistant `icon` attribute (e.g. "mdi:movie-open"), or null when unset.
    function getIcon() {
      return _mIcon;
    }

    function setIcon(newIcon) {
      _mIcon = newIcon;
    }

    // Home Assistant `device_class` attribute (e.g. "battery"), or null when unset.
    function getDeviceClass() {
      return _mDeviceClass;
    }

    function setDeviceClass(newDeviceClass) {
      _mDeviceClass = newDeviceClass;
    }

    function getOptions() {
      return _mOptions;
    }

    function setOptions(newOptions) {
      _mOptions = newOptions;
    }

    function getMin() {
      return _mMin;
    }

    function setMin(newMin) {
      _mMin = newMin;
    }

    function getMax() {
      return _mMax;
    }

    function setMax(newMax) {
      _mMax = newMax;
    }

    function getStep() {
      return _mStep;
    }

    function setStep(newStep) {
      _mStep = newStep;
    }

    function getServiceDomain() {
      return _mServiceDomain;
    }

    function isExternal() {
      return _mExt;
    }

    function isTransitional() {
      return _mState == STATE_CLOSING || _mState == STATE_OPENING || _mState == STATE_LOCKING || _mState == STATE_UNLOCKING;
    }

    function setExternal(isExternal) {
      _mExt = isExternal;
    }
  }
}
