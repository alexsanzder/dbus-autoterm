from __future__ import annotations

import os
import sys
import logging
import time
from dataclasses import dataclass
from enum import IntEnum
from pathlib import Path
from typing import Callable

from controller import STATUS_TEXT
from domain import HeaterPhase, HeaterSnapshot, OperatingMode
from room_sensor import (
    AUTO_ROOM_TEMPERATURE_SERVICE,
    HEATER_INTAKE_TEMPERATURE_SERVICE,
    RoomTemperatureReading,
    RoomTemperatureServiceInfo,
)


class MockVeDbusService:
    def __init__(self, servicename: str) -> None:
        self._paths: dict[str, object] = {}
        self._callbacks: dict[str, Callable[[str, object], bool]] = {}
        self.name = servicename

    def add_path(
        self,
        path: str,
        value: object,
        description: str = "",
        writeable: bool = False,
        onchangecallback: Callable[[str, object], bool] | None = None,
        gettextcallback=None,
        valuetype=None,
        itemtype=None,
    ) -> None:
        del description, writeable, gettextcallback, valuetype, itemtype
        self._paths[path] = value
        if onchangecallback:
            self._callbacks[path] = onchangecallback

    def add_mandatory_paths(
        self,
        processname: str,
        processversion: str,
        connection: str,
        deviceinstance: int,
        productid: int,
        productname: str,
        firmwareversion: str,
        hardwareversion: str,
        connected: int,
    ) -> None:
        self.add_path("/Mgmt/ProcessName", processname)
        self.add_path("/Mgmt/ProcessVersion", processversion)
        self.add_path("/Mgmt/Connection", connection)
        self.add_path("/DeviceInstance", deviceinstance)
        self.add_path("/ProductId", productid)
        self.add_path("/ProductName", productname)
        self.add_path("/FirmwareVersion", firmwareversion)
        self.add_path("/HardwareVersion", hardwareversion)
        self.add_path("/Connected", connected)

    def register(self) -> None:
        return None

    def set_value(self, path: str, value: object) -> None:
        callback = self._callbacks.get(path)
        if callback is None or callback(path, value):
            self._paths[path] = value

    def __getitem__(self, path: str) -> object:
        return self._paths[path]

    def __setitem__(self, path: str, value: object) -> None:
        self._paths[path] = value


def _prime_vedbus_import_path() -> None:
    app_root = Path(__file__).resolve().parent
    candidate = app_root / "ext" / "velib_python"
    if candidate.exists():
        candidate_str = str(candidate)
        if candidate_str not in sys.path:
            sys.path.insert(1, candidate_str)


def build_vedbus_service(service_name: str):
    _prime_vedbus_import_path()
    try:
        import dbus
        from vedbus import VeDbusService
    except Exception as exc:
        raise RuntimeError("VeDbusService is not available. Provide velib_python under ext/velib_python.") from exc

    try:
        if "DBUS_SESSION_BUS_ADDRESS" in os.environ:
            try:
                bus = dbus.SessionBus(private=True)
            except TypeError:
                bus = dbus.SessionBus()
        else:
            try:
                bus = dbus.SystemBus(private=True)
            except TypeError:
                bus = dbus.SystemBus()
        return VeDbusService(service_name, bus=bus, register=False)
    except Exception as exc:
        raise RuntimeError(f"Failed to create VeDbusService for {service_name}: {exc}") from exc


class HeaterUiMode(IntEnum):
    POWER = 0
    TEMPERATURE = 1
    VENTILATION = 2
    HEAT_VENTILATION = 3


class HeaterSensorSource(IntEnum):
    CONTROLLER = 0
    EXTERNAL = 1
    HEATER = 2


class RoomTemperatureSource(IntEnum):
    NONE = 0
    HEATER_EXTERNAL = 1
    CERBO_DBUS = 2


class HeaterState(IntEnum):
    OFF = 0
    STARTING = 1
    WARMING_UP = 2
    RUNNING = 3
    SHUTTING_DOWN = 4
    ERROR = 10


LOG = logging.getLogger(__name__)

@dataclass
class HeaterTimerEntry:
    enabled: int = 0
    cycle: int = 0
    days: int = 0x7F
    start_hour: int = 6
    start_minute: int = 0
    duration_minutes: int = 30
    mode: int = int(HeaterUiMode.POWER)
    target_temperature: int = 20
    power_level: int = 2


@dataclass
@dataclass
class DriverConfig:
    service_name: str = "com.victronenergy.heater.autoterm_air2d"
    device_instance: int = 287
    product_id: int = 0xC06B
    product_name: str = "Autoterm AIR 2D"
    firmware_version: str = "0.1.0"
    hardware_version: str = "AIR2D"
    connection: str = "UART"


class HeaterDbusAdapter:
    def __init__(
        self,
        config: DriverConfig | None = None,
        service=None,
        on_startstop: Callable[[bool], bool] | None = None,
        timer_presets: list[int] | None = None,
        timer_entries: list[HeaterTimerEntry] | None = None,
        timer_mode: int = 0,
    ) -> None:
        self.config = config or DriverConfig()
        self.service = service or build_vedbus_service(self.config.service_name)
        self._on_startstop = on_startstop
        self._on_mode_change: Callable[[int], bool] | None = None
        self._on_target_temperature_change: Callable[[int], bool] | None = None
        self._on_power_level_change: Callable[[int], bool] | None = None
        self._on_room_temperature_service_change: Callable[[str], bool] | None = None
        self._heater_mode = HeaterUiMode.POWER
        self._sensor_source = HeaterSensorSource.EXTERNAL
        self._timers = list(timer_entries) if timer_entries else [HeaterTimerEntry() for _ in range(3)]
        self._timer_duration_minutes = 0
        self._timer_deadline: float | None = None
        self._timer_mode = timer_mode if timer_mode in (0, 2, 3) else 0
        # Indices 0-2 are the HeaterPage "+minutes" steps, 3-5 the preset durations.
        self._timer_presets = [
            max(5 if index < 3 else 30, min(720, int(minutes)))
            for index, minutes in enumerate(timer_presets or [5, 15, 30, 30, 60, 90])
        ]
        self._on_timer_preset_change: Callable[[int, int], bool] | None = None
        self._on_timer_entry_change: Callable[[], None] | None = None
        self._on_timer_mode_change: Callable[[int], bool] | None = None
        # Per-mode stepper memories (Comfort Control p10-12): Power and
        # Ventilation keep independent power levels; Temperature and
        # Heat+Ventilation keep independent setpoints. The heater wire format
        # carries one active settings payload, so switching UI mode reapplies
        # the cached value for that mode.
        self._mode_power = {
            HeaterUiMode.POWER: 2,
            HeaterUiMode.VENTILATION: 2,
            HeaterUiMode.HEAT_VENTILATION: 2,
            HeaterUiMode.TEMPERATURE: 2,
        }
        self._mode_setpoint = {
            HeaterUiMode.TEMPERATURE: 15,
            HeaterUiMode.HEAT_VENTILATION: 15,
        }
        self._init_service()

    def mode_settings_overrides(self) -> dict:
        """Cached stepper values to reapply when the UI mode changes."""
        mode = self._heater_mode
        if mode in {HeaterUiMode.POWER, HeaterUiMode.VENTILATION}:
            return {"power_level": self._mode_power[mode]}
        return {"setpoint_c": self._mode_setpoint[mode]}

    @property
    def timer_mode(self) -> int:
        return self._timer_mode

    @property
    def timer_entries(self) -> list[HeaterTimerEntry]:
        return list(self._timers)

    @property
    def timer_presets(self) -> list[int]:
        return list(self._timer_presets)

    @property
    def current_heater_mode(self) -> HeaterUiMode:
        return self._heater_mode

    @property
    def current_operating_mode(self) -> OperatingMode:
        return self._operating_mode_for_ui()

    def _operating_mode_for_ui(self) -> OperatingMode:
        if self._heater_mode == HeaterUiMode.POWER:
            return OperatingMode.POWER
        return OperatingMode.EXTERNAL_TEMPERATURE

    def _sync_sensor_source_from_mode(self, mode: OperatingMode) -> None:
        if mode == OperatingMode.EXTERNAL_TEMPERATURE:
            self._sensor_source = HeaterSensorSource.EXTERNAL

    def _mode_text(self) -> str:
        return {
            HeaterUiMode.POWER: "Power",
            HeaterUiMode.TEMPERATURE: "Temperature",
            HeaterUiMode.VENTILATION: "Ventilation",
            HeaterUiMode.HEAT_VENTILATION: "Heat + ventilation",
        }[self._heater_mode]

    def _sensor_source_text(self) -> str:
        return {
            HeaterSensorSource.CONTROLLER: "Controller",
            HeaterSensorSource.EXTERNAL: "External",
            HeaterSensorSource.HEATER: "Heater",
        }[self._sensor_source]

    def _room_temperature_source(
        self,
        snapshot: HeaterSnapshot,
        room_temperature_reading: RoomTemperatureReading | None = None,
        selected_service: str = AUTO_ROOM_TEMPERATURE_SERVICE,
    ) -> RoomTemperatureSource:
        if selected_service == HEATER_INTAKE_TEMPERATURE_SERVICE:
            return (
                RoomTemperatureSource.HEATER_EXTERNAL
                if snapshot.telemetry.external_temperature_c is not None
                else RoomTemperatureSource.NONE
            )
        if selected_service not in {"", AUTO_ROOM_TEMPERATURE_SERVICE}:
            return (
                RoomTemperatureSource.CERBO_DBUS
                if room_temperature_reading is not None and room_temperature_reading.temperature_c is not None
                else RoomTemperatureSource.NONE
            )
        if room_temperature_reading is not None and room_temperature_reading.temperature_c is not None:
            return RoomTemperatureSource.CERBO_DBUS
        if snapshot.telemetry.external_temperature_c is not None:
            return RoomTemperatureSource.HEATER_EXTERNAL
        return RoomTemperatureSource.NONE

    def _room_temperature_source_text(
        self,
        snapshot: HeaterSnapshot,
        room_temperature_reading: RoomTemperatureReading | None = None,
        selected_service: str = AUTO_ROOM_TEMPERATURE_SERVICE,
    ) -> str:
        if selected_service == HEATER_INTAKE_TEMPERATURE_SERVICE:
            return (
                "Heater intake sensor"
                if snapshot.telemetry.external_temperature_c is not None
                else "Heater intake sensor unavailable"
            )
        if selected_service not in {"", AUTO_ROOM_TEMPERATURE_SERVICE}:
            return (
                room_temperature_reading.source_text
                if room_temperature_reading is not None
                else "Configured Cerbo temperature sensor unavailable"
            )
        if room_temperature_reading is not None and room_temperature_reading.temperature_c is not None:
            return room_temperature_reading.source_text
        source = self._room_temperature_source(snapshot, room_temperature_reading, selected_service)
        return {
            RoomTemperatureSource.NONE: "Unavailable",
            RoomTemperatureSource.HEATER_EXTERNAL: "Heater intake sensor",
            RoomTemperatureSource.CERBO_DBUS: "Cerbo temperature service",
        }[source]

    def _room_temperature(
        self,
        snapshot: HeaterSnapshot,
        room_temperature_reading: RoomTemperatureReading | None = None,
        selected_service: str = AUTO_ROOM_TEMPERATURE_SERVICE,
    ):
        if selected_service == HEATER_INTAKE_TEMPERATURE_SERVICE:
            return snapshot.telemetry.external_temperature_c
        if room_temperature_reading is not None and room_temperature_reading.temperature_c is not None:
            return room_temperature_reading.temperature_c
        if self._room_temperature_source(snapshot, room_temperature_reading, selected_service) == RoomTemperatureSource.HEATER_EXTERNAL:
            return snapshot.telemetry.external_temperature_c
        return None

    def _room_temperature_control_available(
        self,
        snapshot: HeaterSnapshot,
        room_temperature_reading: RoomTemperatureReading | None = None,
        selected_service: str = AUTO_ROOM_TEMPERATURE_SERVICE,
    ) -> bool:
        return self._room_temperature(snapshot, room_temperature_reading, selected_service) is not None

    def _timer_callback(self, index: int, field: str, minimum: int = 0, maximum: int | None = None):
        def _callback(path: str, value: object) -> bool:
            del path
            timer = self._timers[index]
            numeric = int(value)
            if maximum is not None:
                numeric = min(maximum, numeric)
            numeric = max(minimum, numeric)
            setattr(timer, field, numeric)
            LOG.info("SCHEDWRT T%d %s = %s (raw %r)", index, field, numeric, value)
            self._notify_timer_entry_change()
            return True

        return _callback

    def _notify_timer_entry_change(self) -> None:
        if self._on_timer_entry_change is not None:
            self._on_timer_entry_change()

    def _init_service(self) -> None:
        self.service.add_mandatory_paths(
            processname=__file__,
            processversion=self.config.firmware_version,
            connection=self.config.connection,
            deviceinstance=self.config.device_instance,
            productid=self.config.product_id,
            productname=self.config.product_name,
            firmwareversion=self.config.firmware_version,
            hardwareversion=self.config.hardware_version,
            connected=1,
        )
        self.service.add_path("/CustomName", self.config.product_name)
        self.service.add_path("/Role", "heater")
        self.service.add_path("/State", int(HeaterState.OFF))
        self.service.add_path("/StateText", "off")
        self.service.add_path("/Mode", int(self._heater_mode), writeable=True, onchangecallback=self._handle_heater_mode_change)
        self.service.add_path("/ModeText", self._mode_text())
        self.service.add_path("/StartStop", 0, writeable=True, onchangecallback=self._handle_startstop)
        self.service.add_path("/Runtime", 0)
        self.service.add_path("/ErrorCode", 0)
        self.service.add_path("/ErrorText", "")
        self.service.add_path("/Alarms/Communication", 0)
        self.service.add_path("/Dc/0/Voltage", 0.0)
        self.service.add_path("/Temperatures/Room", None)
        self.service.add_path("/Temperatures/RoomSource", int(RoomTemperatureSource.NONE))
        self.service.add_path("/Temperatures/RoomSourceText", "Unavailable")
        self.service.add_path("/Temperatures/Internal", None)
        self.service.add_path("/Temperatures/Control", None)
        self.service.add_path("/Temperatures/Heater", None)
        self.service.add_path("/Capabilities/RoomTemperatureControl", 0)
        self.service.add_path("/Capabilities/ExternalRoomSensor", 0)
        self.service.add_path("/Capabilities/CerboRoomSensor", 0)
        self.service.add_path("/Status/FanRpmSet", 0)
        self.service.add_path("/Status/FanRpmActual", 0)
        self.service.add_path("/Status/FuelPumpFrequency", 0.0)
        self.service.add_path("/Settings/Mode", int(OperatingMode.POWER))
        self.service.add_path(
            "/Settings/TargetTemperature",
            15,
            writeable=True,
            onchangecallback=self._handle_target_temperature_change,
        )
        self.service.add_path(
            "/Settings/PowerLevel",
            2,
            writeable=True,
            onchangecallback=self._handle_power_level_change,
        )
        self.service.add_path(
            "/Settings/RoomTemperatureService",
            "auto",
            writeable=True,
            onchangecallback=self._handle_room_temperature_service_change,
        )
        self.service.add_path("/Settings/RoomTemperatureServiceText", "Automatic")
        self.service.add_path("/AvailableRoomSensors/Count", 0)
        for index in range(8):
            prefix = f"/AvailableRoomSensors/{index}"
            self.service.add_path(f"{prefix}/Name", "")
            self.service.add_path(f"{prefix}/Service", "")
            self.service.add_path(f"{prefix}/Temperature", None)
        for index in range(len(self._timers)):
            prefix = f"/Timers/{index}"
            self.service.add_path(f"{prefix}/Enabled", self._timers[index].enabled, writeable=True, onchangecallback=self._timer_callback(index, "enabled", 0, 1), valuetype=int)
            self.service.add_path(f"{prefix}/Cycle", self._timers[index].cycle, writeable=True, onchangecallback=self._timer_callback(index, "cycle", 0, 2), valuetype=int)
            self.service.add_path(f"{prefix}/Days", self._timers[index].days, writeable=True, onchangecallback=self._timer_callback(index, "days", 0, 0x7F), valuetype=int)
            self.service.add_path(f"{prefix}/StartHour", self._timers[index].start_hour, writeable=True, onchangecallback=self._timer_callback(index, "start_hour", 0, 23), valuetype=int)
            self.service.add_path(f"{prefix}/StartMinute", self._timers[index].start_minute, writeable=True, onchangecallback=self._timer_callback(index, "start_minute", 0, 59), valuetype=int)
            self.service.add_path(f"{prefix}/StartTime", self._timers[index].start_hour * 3600 + self._timers[index].start_minute * 60, writeable=True, onchangecallback=self._timer_start_time_callback(index), valuetype=int)
            self.service.add_path(f"{prefix}/DurationMinutes", self._timers[index].duration_minutes, writeable=True, onchangecallback=self._timer_callback(index, "duration_minutes", 1, 24 * 60), valuetype=int)
            self.service.add_path(f"{prefix}/Mode", self._timers[index].mode, writeable=True, onchangecallback=self._timer_callback(index, "mode", int(HeaterUiMode.POWER), int(HeaterUiMode.HEAT_VENTILATION)), valuetype=int)
            self.service.add_path(f"{prefix}/TargetTemperature", self._timers[index].target_temperature, writeable=True, onchangecallback=self._timer_callback(index, "target_temperature", 0, 30), valuetype=int)
            self.service.add_path(f"{prefix}/PowerLevel", self._timers[index].power_level, writeable=True, onchangecallback=self._timer_callback(index, "power_level", 1, 9), valuetype=int)
        self.service.add_path("/Timer/DurationMinutes", 0, writeable=True, onchangecallback=self._handle_timer_duration_change, valuetype=int)
        self.service.add_path("/Timer/RemainingSeconds", 0, valuetype=int)
        self.service.add_path("/Timer/Mode", self._timer_mode, writeable=True, onchangecallback=self._handle_timer_mode_change, valuetype=int)
        for index in range(len(self._timer_presets)):
            self.service.add_path(f"/Settings/Timer/Preset/{index}", self._timer_presets[index], writeable=True, onchangecallback=self._handle_timer_preset_change(index), valuetype=int)
        self.service.register()

    def _handle_startstop(self, path: str, value: object) -> bool:
        del path
        if self._on_startstop is None:
            return False
        return self._on_startstop(bool(value))

    def _handle_heater_mode_change(self, path: str, value: object) -> bool:
        del path
        try:
            new_mode = HeaterUiMode(int(value))
        except ValueError:
            return False
        if new_mode in {HeaterUiMode.TEMPERATURE, HeaterUiMode.HEAT_VENTILATION} and self.service["/Capabilities/RoomTemperatureControl"] != 1:
            return False
        # Manual: impossible to switch to any heating mode while the heater is
        # operating in ventilation mode.
        if new_mode is not HeaterUiMode.VENTILATION and self.service["/StateText"] in {
            "starting ventilation",
            "ventilation",
            "stopping ventilation",
        }:
            return False

        previous_mode = self._heater_mode
        self._heater_mode = new_mode
        if self._on_mode_change is None:
            self._heater_mode = previous_mode
            return False
        if self._on_mode_change(int(self._operating_mode_for_ui())):
            return True
        self._heater_mode = previous_mode
        return False

    def _handle_sensor_source_change(self, path: str, value: object) -> bool:
        del path
        del value
        return False

    def _handle_room_temperature_service_change(self, path: str, value: object) -> bool:
        del path
        if self._on_room_temperature_service_change is None:
            return False
        return self._on_room_temperature_service_change(str(value))

    def _handle_target_temperature_change(self, path: str, value: object) -> bool:
        del path
        try:
            setpoint = int(value)
        except (TypeError, ValueError):
            return False
        if self._heater_mode in self._mode_setpoint:
            self._mode_setpoint[self._heater_mode] = setpoint
        if self._on_target_temperature_change is None:
            return False
        return self._on_target_temperature_change(setpoint)

    def _handle_timer_duration_change(self, path: str, value: object) -> bool:
        del path
        try:
            minutes = int(value)
        except (TypeError, ValueError):
            return False
        if minutes != 0:
            minutes = max(30, min(720, minutes))
        self._timer_duration_minutes = minutes
        self._timer_deadline = None
        return True

    def _timer_start_time_callback(self, index: int):
        def _callback(path: str, value: object) -> bool:
            del path
            try:
                seconds = int(value)
            except (TypeError, ValueError):
                return False
            seconds = max(0, min(24 * 60 * 60 - 1, seconds))
            timer = self._timers[index]
            timer.start_hour = seconds // 3600
            timer.start_minute = (seconds % 3600) // 60
            self._notify_timer_entry_change()
            return True

        return _callback

    def _handle_timer_mode_change(self, path: str, value: object) -> bool:
        del path
        try:
            mode = int(value)
        except (TypeError, ValueError):
            return False
        if mode not in (0, 2, 3):
            return False
        self._timer_mode = mode
        if self._on_timer_mode_change is not None and not self._on_timer_mode_change(mode):
            return False
        return True

    def _handle_timer_preset_change(self, index: int):
        def _callback(path: str, value: object) -> bool:
            del path
            try:
                minutes = int(value)
            except (TypeError, ValueError):
                return False
            minutes = max(5 if index < 3 else 30, min(720, minutes))
            self._timer_presets[index] = minutes
            if self._on_timer_preset_change is not None and not self._on_timer_preset_change(index, minutes):
                return False
            return True

        return _callback

    def _handle_power_level_change(self, path: str, value: object) -> bool:
        del path
        try:
            level = int(value)
        except (TypeError, ValueError):
            return False
        self._mode_power[self._heater_mode] = level
        if self._on_power_level_change is None:
            return False
        return self._on_power_level_change(level)

    def _publish_timer(self, snapshot: HeaterSnapshot, is_connected: bool) -> None:
        duration = self._timer_duration_minutes
        active = is_connected and snapshot.phase in {
            HeaterPhase.STARTING,
            HeaterPhase.WARMING_UP,
            HeaterPhase.RUNNING,
        }
        if not active or duration == 0:
            self._timer_deadline = None
            self.service["/Timer/RemainingSeconds"] = duration * 60
            return
        if self._timer_deadline is None:
            self._timer_deadline = time.monotonic() + duration * 60
        remaining = max(0, int(round(self._timer_deadline - time.monotonic())))
        if remaining == 0:
            self._timer_duration_minutes = 0
            self._timer_deadline = None
            if self._on_startstop is not None:
                self._on_startstop(False)
        self.service["/Timer/RemainingSeconds"] = remaining

    def _heater_state(self, snapshot: HeaterSnapshot, is_connected: bool) -> int:
        if not is_connected or snapshot.telemetry.error_code:
            return int(HeaterState.ERROR)
        return {
            HeaterPhase.OFF: HeaterState.OFF,
            HeaterPhase.STARTING: HeaterState.STARTING,
            HeaterPhase.WARMING_UP: HeaterState.WARMING_UP,
            HeaterPhase.RUNNING: HeaterState.RUNNING,
            HeaterPhase.SHUTTING_DOWN: HeaterState.SHUTTING_DOWN,
        }[snapshot.phase]

    def _heater_state_text(self, snapshot: HeaterSnapshot, is_connected: bool) -> str:
        if not is_connected:
            return "not connected"
        if snapshot.telemetry.error_code:
            return "fault"
        if snapshot.ventilation_mode:
            if snapshot.phase == HeaterPhase.STARTING:
                return "starting ventilation"
            if snapshot.phase == HeaterPhase.SHUTTING_DOWN:
                return "stopping ventilation"
            if snapshot.phase == HeaterPhase.RUNNING:
                return "ventilation"
        return STATUS_TEXT.get(snapshot.phase, "unknown")

    def _error_text(self, snapshot: HeaterSnapshot, is_connected: bool) -> str:
        if not is_connected:
            return "Communication error"
        if snapshot.telemetry.error_code:
            return f"Heater error {snapshot.telemetry.error_code}"
        return ""

    def _control_temperature(self, snapshot: HeaterSnapshot):
        return self._room_temperature(snapshot)

    def publish_snapshot(
        self,
        snapshot: HeaterSnapshot,
        connected: bool,
        room_temperature_reading: RoomTemperatureReading | None = None,
        selected_room_temperature_service: str = AUTO_ROOM_TEMPERATURE_SERVICE,
    ) -> None:
        is_connected = bool(connected and snapshot.connected)
        room_temperature = self._room_temperature(snapshot, room_temperature_reading, selected_room_temperature_service)
        room_source = self._room_temperature_source(snapshot, room_temperature_reading, selected_room_temperature_service)
        room_control_available = self._room_temperature_control_available(
            snapshot,
            room_temperature_reading,
            selected_room_temperature_service,
        )

        if snapshot.ventilation_mode:
            self._heater_mode = HeaterUiMode.VENTILATION
        elif self._heater_mode in {HeaterUiMode.VENTILATION, HeaterUiMode.HEAT_VENTILATION}:
            pass
        elif snapshot.settings.mode == OperatingMode.POWER:
            self._heater_mode = HeaterUiMode.POWER
        elif not room_control_available:
            self._heater_mode = HeaterUiMode.POWER
        else:
            self._heater_mode = HeaterUiMode.TEMPERATURE
        self._sync_sensor_source_from_mode(snapshot.settings.mode)
        # Keep the active mode's memory in sync with what the heater reports;
        # other modes keep their independent cached values.
        self._mode_power[self._heater_mode] = snapshot.settings.power_level
        if self._heater_mode in self._mode_setpoint:
            self._mode_setpoint[self._heater_mode] = snapshot.settings.setpoint_c

        self.service["/Connected"] = 1 if is_connected else 0
        self.service["/State"] = self._heater_state(snapshot, is_connected)
        self.service["/StateText"] = self._heater_state_text(snapshot, is_connected)
        self.service["/Mode"] = int(self._heater_mode)
        self.service["/ModeText"] = self._mode_text()
        self.service["/StartStop"] = 1 if snapshot.phase in {HeaterPhase.STARTING, HeaterPhase.WARMING_UP, HeaterPhase.RUNNING} else 0
        self.service["/Runtime"] = snapshot.runtime_seconds
        self.service["/ErrorCode"] = snapshot.telemetry.error_code if is_connected else 1
        self.service["/ErrorText"] = self._error_text(snapshot, is_connected)
        self.service["/Alarms/Communication"] = 0 if is_connected else 2
        self.service["/Dc/0/Voltage"] = snapshot.telemetry.battery_voltage_v
        self.service["/Temperatures/Room"] = room_temperature
        self.service["/Temperatures/RoomSource"] = int(room_source)
        self.service["/Temperatures/RoomSourceText"] = self._room_temperature_source_text(
            snapshot,
            room_temperature_reading,
            selected_room_temperature_service,
        )
        self.service["/Temperatures/Internal"] = snapshot.telemetry.internal_temperature_c
        self.service["/Temperatures/Control"] = room_temperature
        self.service["/Temperatures/Heater"] = snapshot.telemetry.heater_temperature_c
        self.service["/Capabilities/RoomTemperatureControl"] = 1 if room_control_available else 0
        self.service["/Capabilities/ExternalRoomSensor"] = 1 if snapshot.telemetry.external_temperature_c is not None else 0
        self.service["/Capabilities/CerboRoomSensor"] = 1 if room_source == RoomTemperatureSource.CERBO_DBUS else 0
        self.service["/Status/FanRpmSet"] = snapshot.telemetry.fan_rpm_set
        self.service["/Status/FanRpmActual"] = snapshot.telemetry.fan_rpm_actual
        self.service["/Status/FuelPumpFrequency"] = snapshot.telemetry.fuel_pump_frequency_hz
        self.service["/Settings/Mode"] = int(snapshot.settings.mode)
        self.service["/Settings/TargetTemperature"] = snapshot.settings.setpoint_c
        self.service["/Settings/PowerLevel"] = snapshot.settings.power_level
        self._publish_timer(snapshot, is_connected)

    def publish_room_temperature_services(
        self,
        services: list[RoomTemperatureServiceInfo],
        selected_service: str,
    ) -> None:
        normalized_service = selected_service or AUTO_ROOM_TEMPERATURE_SERVICE
        self.service["/Settings/RoomTemperatureService"] = normalized_service
        if normalized_service in {"", AUTO_ROOM_TEMPERATURE_SERVICE}:
            self.service["/Settings/RoomTemperatureServiceText"] = "Automatic"
        else:
            selected = next((service for service in services if service.service_name == normalized_service), None)
            self.service["/Settings/RoomTemperatureServiceText"] = (
                selected.display_name
                if selected is not None
                else (
                    "Heater intake sensor unavailable"
                    if normalized_service == HEATER_INTAKE_TEMPERATURE_SERVICE
                    else "Configured sensor unavailable"
                )
            )

        self.service["/AvailableRoomSensors/Count"] = len(services)
        for index in range(8):
            prefix = f"/AvailableRoomSensors/{index}"
            if index < len(services):
                service = services[index]
                self.service[f"{prefix}/Name"] = service.display_name
                self.service[f"{prefix}/Service"] = service.service_name
                self.service[f"{prefix}/Temperature"] = service.temperature_c
            else:
                self.service[f"{prefix}/Name"] = ""
                self.service[f"{prefix}/Service"] = ""
                self.service[f"{prefix}/Temperature"] = None
