import unittest
import unittest.mock

from app import HeaterDriverApp
from domain import HeaterPhase, HeaterSnapshot
from gx_dbus import DriverConfig, HeaterDbusAdapter, MockVeDbusService
from protocol import CONTROLLER_PROFILE, Frame
from provider import DummyHeaterProvider, SerialHeaterProvider, SerialProviderConfig
from room_sensor import HEATER_INTAKE_TEMPERATURE_SERVICE, RoomTemperatureReading


class DriverTests(unittest.TestCase):
    def _build_app(self, room_temperature_reader=None):
        provider = DummyHeaterProvider()
        provider.connect()
        service = MockVeDbusService("com.victronenergy.heater.autoterm_air2d")
        adapter = HeaterDbusAdapter(config=DriverConfig(), service=service)
        app = HeaterDriverApp(provider, adapter, room_temperature_reader=room_temperature_reader)
        adapter._on_startstop = app.startstop
        adapter._on_mode_change = app.update_mode
        adapter._on_target_temperature_change = app.update_target_temperature
        adapter._on_power_level_change = app.update_power_level
        adapter._on_room_temperature_service_change = app.update_room_temperature_service
        return provider, service, app

    def test_dummy_provider_updates_mock_dbus(self):
        _, service, app = self._build_app()

        app.run_once()
        self.assertEqual(service["/Connected"], 1)
        self.assertEqual(service["/State"], 0)
        self.assertEqual(service["/StateText"], "off")
        self.assertEqual(service["/Role"], "heater")
        self.assertEqual(service["/ModeText"], "Power")
        self.assertEqual(service["/Capabilities/RoomTemperatureControl"], 0)
        self.assertIsNone(service["/Temperatures/Room"])
        self.assertEqual(service["/Timers/0/Enabled"], 0)
        self.assertEqual(service["/Timers/2/Mode"], 1)

    def test_startstop_callback_updates_state(self):
        _, service, _ = self._build_app()

        service.set_value("/StartStop", 1)
        self.assertEqual(service["/StartStop"], 1)
        self.assertIn(service["/State"], {1, 2, 3})
        self.assertEqual(service["/Alarms/Communication"], 0)

        service.set_value("/StartStop", 0)
        self.assertEqual(service["/StartStop"], 0)

    def test_disconnected_provider_maps_to_communication_alarm(self):
        provider, service, app = self._build_app()
        provider.close()

        app.run_once()
        self.assertEqual(service["/Connected"], 0)
        self.assertEqual(service["/Alarms/Communication"], 2)
        self.assertEqual(service["/ErrorText"], "Communication error")

    def test_settings_callbacks_propagate_to_provider_snapshot(self):
        _, service, app = self._build_app()

        service.set_value("/Settings/TargetTemperature", 21)
        service.set_value("/Settings/PowerLevel", 5)

        app.run_once()
        self.assertEqual(service["/Mode"], 0)
        self.assertEqual(service["/Settings/TargetTemperature"], 21)
        self.assertEqual(service["/Settings/PowerLevel"], 5)

    def test_runtime_exports_live_metrics(self):
        _, service, app = self._build_app()

        service.set_value("/StartStop", 1)
        app.run_once()

        self.assertGreaterEqual(service["/Status/FanRpmActual"], 0)
        self.assertIsNone(service["/Temperatures/Control"])
        self.assertGreater(service["/Dc/0/Voltage"], 0.0)

    def test_external_room_sensor_enables_temperature_control(self):
        provider, service, app = self._build_app()
        provider._snapshot.telemetry.external_temperature_c = 18

        app.run_once()
        service.set_value("/Mode", 1)
        app.run_once()

        self.assertEqual(service["/Capabilities/RoomTemperatureControl"], 1)
        self.assertEqual(service["/Temperatures/Room"], 18)
        self.assertEqual(service["/Temperatures/RoomSourceText"], "Heater intake sensor")
        self.assertEqual(service["/Mode"], 1)

    def test_explicit_heater_intake_sensor_overrides_cerbo_room_sensor(self):
        class _Reader:
            selected_service = HEATER_INTAKE_TEMPERATURE_SERVICE

            def refresh(self):
                return RoomTemperatureReading(
                    temperature_c=20.5,
                    source_text="Salon",
                    service_name="com.victronenergy.temperature.ttyO1",
                )

            def available_services(self):
                return []

            def set_selected_service(self, service_name: str):
                self.selected_service = service_name

        provider, service, app = self._build_app(room_temperature_reader=_Reader())
        provider._snapshot.telemetry.external_temperature_c = 18

        app.run_once()
        service.set_value("/Mode", 1)
        app.run_once()

        self.assertEqual(service["/Temperatures/Room"], 18)
        self.assertEqual(service["/Temperatures/RoomSourceText"], "Heater intake sensor")
        self.assertEqual(service["/Settings/RoomTemperatureService"], HEATER_INTAKE_TEMPERATURE_SERVICE)

    def test_cerbo_room_sensor_enables_temperature_control(self):
        class _Reader:
            selected_service = "auto"

            def refresh(self):
                return RoomTemperatureReading(
                    temperature_c=20.5,
                    source_text="Salon",
                    service_name="com.victronenergy.temperature.ttyO1",
                )

            def available_services(self):
                return []

            def set_selected_service(self, service_name: str):
                self.selected_service = service_name

        _, service, app = self._build_app(room_temperature_reader=_Reader())

        app.run_once()
        service.set_value("/Mode", 1)
        app.run_once()

        self.assertEqual(service["/Capabilities/RoomTemperatureControl"], 1)
        self.assertEqual(service["/Capabilities/CerboRoomSensor"], 1)
        self.assertEqual(service["/Temperatures/Room"], 20.5)
        self.assertEqual(service["/Temperatures/RoomSourceText"], "Salon")
        self.assertEqual(service["/Mode"], 1)

    def test_power_level_change_preserves_room_sensor_context(self):
        class _Reader:
            selected_service = "auto"

            def refresh(self):
                return RoomTemperatureReading(
                    temperature_c=20.5,
                    source_text="Salon",
                    service_name="com.victronenergy.temperature.ttyO1",
                )

            def available_services(self):
                return []

            def set_selected_service(self, service_name: str):
                self.selected_service = service_name

        _, service, app = self._build_app(room_temperature_reader=_Reader())

        app.run_once()
        service.set_value("/Settings/PowerLevel", 5)

        self.assertEqual(service["/Temperatures/Room"], 20.5)
        self.assertEqual(service["/Temperatures/RoomSourceText"], "Salon")
        self.assertEqual(service["/Settings/PowerLevel"], 5)

    def test_room_temperature_service_selection_round_trips(self):
        class _Reader:
            def __init__(self):
                self.selected_service = "auto"

            def refresh(self):
                return RoomTemperatureReading()

            def available_services(self):
                from room_sensor import RoomTemperatureServiceInfo

                return [
                    RoomTemperatureServiceInfo(
                        service_name="com.victronenergy.temperature.ttyO1",
                        display_name="Salon",
                        temperature_c=21.0,
                    )
                ]

            def set_selected_service(self, service_name: str):
                self.selected_service = service_name

        reader = _Reader()
        _, service, app = self._build_app(room_temperature_reader=reader)

        app.run_once()
        service.set_value("/Settings/RoomTemperatureService", "com.victronenergy.temperature.ttyO1")

        self.assertEqual(reader.selected_service, "com.victronenergy.temperature.ttyO1")
        self.assertEqual(service["/Settings/RoomTemperatureService"], "com.victronenergy.temperature.ttyO1")
        self.assertEqual(service["/Settings/RoomTemperatureServiceText"], "Salon")

    def test_heater_intake_sensor_selection_round_trips(self):
        provider, service, app = self._build_app()
        provider._snapshot.telemetry.external_temperature_c = 17

        app.run_once()
        service.set_value("/Settings/RoomTemperatureService", HEATER_INTAKE_TEMPERATURE_SERVICE)

        self.assertEqual(service["/Settings/RoomTemperatureService"], HEATER_INTAKE_TEMPERATURE_SERVICE)
        self.assertEqual(service["/Settings/RoomTemperatureServiceText"], "Heater intake sensor")

    def test_explicit_unavailable_cerbo_sensor_does_not_fallback_to_heater_intake(self):
        class _Reader:
            selected_service = "com.victronenergy.temperature.missing"

            def refresh(self):
                return RoomTemperatureReading(
                    temperature_c=None,
                    source_text="Configured Cerbo temperature sensor unavailable",
                    service_name=self.selected_service,
                )

            def available_services(self):
                return []

            def set_selected_service(self, service_name: str):
                self.selected_service = service_name

        provider, service, app = self._build_app(room_temperature_reader=_Reader())
        provider._snapshot.telemetry.external_temperature_c = 18

        app.run_once()

        self.assertEqual(service["/Capabilities/RoomTemperatureControl"], 0)
        self.assertIsNone(service["/Temperatures/Room"])
        self.assertEqual(service["/Temperatures/RoomSourceText"], "Configured Cerbo temperature sensor unavailable")

    def test_temperature_mode_is_rejected_without_room_sensor(self):
        _, service, app = self._build_app()

        app.run_once()
        service.set_value("/Mode", 1)

        self.assertEqual(service["/Mode"], 0)

    def test_ventilation_mode_uses_primary_heater_contract(self):
        _, service, app = self._build_app()

        service.set_value("/Mode", 2)
        service.set_value("/Settings/PowerLevel", 4)
        service.set_value("/StartStop", 1)
        app.run_once()

        self.assertEqual(service["/ModeText"], "Ventilation")
        self.assertIn(service["/StateText"], {"starting ventilation", "ventilation"})
        self.assertEqual(service["/Status/FuelPumpFrequency"], 0.0)

    def test_idle_ventilation_mode_survives_power_level_changes(self):
        _, service, app = self._build_app()

        service.set_value("/Mode", 2)
        app.run_once()
        service.set_value("/Settings/PowerLevel", 4)
        app.run_once()

        self.assertEqual(service["/Mode"], 2)
        self.assertEqual(service["/ModeText"], "Ventilation")
        self.assertEqual(service["/Settings/PowerLevel"], 4)

    def test_timer_paths_round_trip(self):
        _, service, _ = self._build_app()

        service.set_value("/Timers/1/Enabled", 1)
        service.set_value("/Timers/1/StartHour", 22)
        service.set_value("/Timers/1/DurationMinutes", 90)

        self.assertEqual(service["/Timers/1/Enabled"], 1)
        self.assertEqual(service["/Timers/1/StartHour"], 22)
        self.assertEqual(service["/Timers/1/DurationMinutes"], 90)

    def test_startstop_transitions_back_to_off(self):
        provider, service, app = self._build_app()

        service.set_value("/StartStop", 1)
        app.run_once()
        service.set_value("/StartStop", 0)
        provider._set_phase(HeaterPhase.OFF)
        app.run_once()

        self.assertEqual(service["/State"], 0)
        self.assertEqual(service["/StartStop"], 0)

    def test_serial_provider_ignores_echoed_settings_request_frame(self):
        provider = SerialHeaterProvider(SerialProviderConfig(device="/dev/null", profile=CONTROLLER_PROFILE), stream=object())
        request = Frame(device=CONTROLLER_PROFILE.controller_device, message_id2=0x02)
        echoed_request = Frame(device=CONTROLLER_PROFILE.controller_device, message_id2=0x02)
        heater_response = Frame(device=CONTROLLER_PROFILE.heater_device, message_id2=0x02, payload=b"\x01\x00\x04\x0f\x00\x02")

        self.assertFalse(provider._matches_response(request, echoed_request))
        self.assertTrue(provider._matches_response(request, heater_response))


class TimerCountdownTest(unittest.TestCase):
    def _build_adapter(self, on_startstop=None):
        service = MockVeDbusService("com.victronenergy.heater.autoterm_air2d")
        adapter = HeaterDbusAdapter(config=DriverConfig(), service=service, on_startstop=on_startstop)
        return service, adapter

    def test_arm_timer_publishes_full_remaining_when_off(self):
        _, service, app = DriverTests()._build_app()

        service.set_value("/Timer/DurationMinutes", 30)
        self.assertEqual(service["/Timer/DurationMinutes"], 30)
        app.run_once()

        self.assertEqual(service["/Timer/RemainingSeconds"], 1800)
        self.assertEqual(service["/Timer/DurationMinutes"], 30)

    def test_countdown_ticks_and_expiry_stops_heater(self):
        stops = []
        service, adapter = self._build_adapter(on_startstop=lambda enabled: stops.append(enabled) or True)
        adapter.service.set_value("/Timer/DurationMinutes", 30)
        running = HeaterSnapshot(phase=HeaterPhase.RUNNING)

        adapter.publish_snapshot(running, True)
        self.assertGreaterEqual(service["/Timer/RemainingSeconds"], 1798)
        self.assertLessEqual(service["/Timer/RemainingSeconds"], 1800)

        with unittest.mock.patch("gx_dbus.time.monotonic", return_value=adapter._timer_deadline + 10):
            adapter.publish_snapshot(running, True)

        self.assertEqual(service["/Timer/RemainingSeconds"], 0)
        self.assertEqual(adapter._timer_duration_minutes, 0)
        self.assertEqual(stops, [False])

    def test_duration_clamped_and_zero_cancels(self):
        service, adapter = self._build_adapter()

        service.set_value("/Timer/DurationMinutes", 5)
        self.assertEqual(adapter._timer_duration_minutes, 30)
        service.set_value("/Timer/DurationMinutes", 800)
        self.assertEqual(adapter._timer_duration_minutes, 720)
        service.set_value("/Timer/DurationMinutes", 0)
        self.assertEqual(adapter._timer_duration_minutes, 0)

    def test_timer_presets_default_and_clamped(self):
        service, adapter = self._build_adapter()

        self.assertEqual(adapter.timer_presets, [30, 60, 90])
        self.assertEqual(service["/Settings/Timer/Preset/0"], 30)

        service.set_value("/Settings/Timer/Preset/1", 40)
        self.assertEqual(adapter.timer_presets[1], 40)

        service.set_value("/Settings/Timer/Preset/2", 5)
        self.assertEqual(adapter.timer_presets[2], 30)
        service.set_value("/Settings/Timer/Preset/2", 900)
        self.assertEqual(adapter.timer_presets[2], 720)
        service.set_value("/Settings/Timer/Preset/0", "junk")
        self.assertEqual(adapter.timer_presets[0], 30)

    def test_timer_presets_custom_initial_values(self):
        service = MockVeDbusService("com.victronenergy.heater.autoterm_air2d")
        adapter = HeaterDbusAdapter(
            config=DriverConfig(),
            service=service,
            timer_presets=[40, 50, 60],
        )

        self.assertEqual(adapter.timer_presets, [40, 50, 60])
        self.assertEqual(service["/Settings/Timer/Preset/2"], 60)


if __name__ == "__main__":
    unittest.main()
