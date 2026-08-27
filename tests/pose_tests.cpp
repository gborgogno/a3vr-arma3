#include "../src/pose.hpp"
#include "../src/freetrack_output.hpp"
#include "../src/controller_aim_output.hpp"
#include "../src/controller_input_output.hpp"
#include "../src/absolute_weapon_pose.hpp"
#include "../src/game_context.hpp"

#include <cassert>
#include <cmath>
#include <windows.h>

namespace {
bool approximately_equal(const float a, const float b) { return std::abs(a - b) < 0.0001F; }
}

int main() {
    SetEnvironmentVariableA("A3VR_CONTROLLER_AIM", nullptr);
    SetEnvironmentVariableA("A3VR_CONTROLLER_BUTTONS", nullptr);
    SetEnvironmentVariableA("A3VR_SMOOTH_TURN", nullptr);
    const a3vr::ControllerAimOutput default_aim;
    const a3vr::ControllerInputOutput default_input;
    assert(default_aim.enabled());
    assert(default_input.enabled());
    assert(default_input.smooth_turn_enabled());

    SetEnvironmentVariableA("A3VR_CONTROLLER_AIM", "0");
    SetEnvironmentVariableA("A3VR_CONTROLLER_BUTTONS", "0");
    SetEnvironmentVariableA("A3VR_SMOOTH_TURN", "0");
    const a3vr::ControllerAimOutput disabled_aim;
    const a3vr::ControllerInputOutput disabled_input;
    assert(!disabled_aim.enabled());
    assert(!disabled_input.enabled());
    assert(!disabled_input.smooth_turn_enabled());

    const auto mapped = a3vr::xr_to_arma_position({1.0F, 2.0F, 3.0F});
    assert(approximately_equal(mapped.x, 1.0F) && approximately_equal(mapped.y, -3.0F) && approximately_equal(mapped.z, 2.0F));

    const a3vr::Quat identity{};
    const auto direction = a3vr::arma_direction(identity);
    const auto up = a3vr::arma_up(identity);
    assert(approximately_equal(direction.x, 0.0F) && approximately_equal(direction.y, 1.0F) && approximately_equal(direction.z, 0.0F));
    assert(approximately_equal(up.x, 0.0F) && approximately_equal(up.y, 0.0F) && approximately_equal(up.z, 1.0F));

    a3vr::TrackedPose tracked{};
    tracked.position = {1.0F, 2.0F, -3.0F};
    tracked.orientation = identity;
    const auto freetrack = a3vr::to_freetrack_pose(tracked);
    assert(approximately_equal(freetrack.yaw, 0.0F));
    assert(approximately_equal(freetrack.pitch, 0.0F));
    assert(approximately_equal(freetrack.roll, 0.0F));
    assert(approximately_equal(freetrack.x, -100.0F));
    assert(approximately_equal(freetrack.y, 100.0F));
    assert(approximately_equal(freetrack.z, 100.0F));

    const auto recessed = a3vr::apply_body_recess({}, 220.0F);
    assert(approximately_equal(recessed.z, 220.0F));
    const auto limited_recess = a3vr::apply_body_recess({}, 900.0F);
    assert(approximately_equal(limited_recess.z, 400.0F));

    const float half_angle = 0.25F;
    tracked.position = {};
    tracked.orientation = {0.0F, std::sin(half_angle), 0.0F, std::cos(half_angle)};
    const auto limited_rotation = a3vr::to_freetrack_pose(tracked);
    assert(approximately_equal(limited_rotation.yaw, 0.21F));
    assert(approximately_equal(limited_rotation.pitch, 0.0F));

    tracked.orientation = {std::sin(half_angle), 0.0F, 0.0F, std::cos(half_angle)};
    const auto limited_vertical = a3vr::to_freetrack_pose(tracked);
    assert(approximately_equal(limited_vertical.yaw, 0.0F));
    assert(approximately_equal(limited_vertical.pitch, 0.21F));

    const float over_vertical_half_angle = 0.87266463F; // 100 degrees total
    tracked.orientation = {std::sin(over_vertical_half_angle), 0.0F, 0.0F,
                           std::cos(over_vertical_half_angle)};
    const auto over_vertical = a3vr::to_freetrack_pose(tracked, 1.0F);
    assert(approximately_equal(over_vertical.yaw, 0.0F));
    assert(approximately_equal(over_vertical.pitch, 0.87266463F));

    a3vr::TrackedPose controller{};
    controller.orientation_valid = true;
    controller.orientation = {0.0F, std::sin(half_angle), 0.0F, std::cos(half_angle)};
    const auto controller_yaw = a3vr::controller_angles_world(controller);
    assert(approximately_equal(controller_yaw.yaw, -0.5F));
    assert(approximately_equal(controller_yaw.pitch, 0.0F));
    const auto controller_yaw_as_arma = a3vr::arma_direction_angles(
        a3vr::arma_direction(controller.orientation));
    assert(approximately_equal(controller_yaw_as_arma.yaw, controller_yaw.yaw));
    assert(approximately_equal(controller_yaw_as_arma.pitch, controller_yaw.pitch));

    controller.orientation = {std::sin(half_angle), 0.0F, 0.0F, std::cos(half_angle)};
    const auto controller_pitch = a3vr::controller_angles_world(controller);
    assert(approximately_equal(controller_pitch.yaw, 0.0F));
    assert(approximately_equal(controller_pitch.pitch, 0.5F));

    const auto arma_forward_angles = a3vr::arma_direction_angles({0.0F, 1.0F, 0.0F});
    assert(approximately_equal(arma_forward_angles.yaw, 0.0F));
    assert(approximately_equal(arma_forward_angles.pitch, 0.0F));
    const auto uncorrected_servo = a3vr::absolute_aim_correction(
        {0.40F, 0.10F}, {0.0F, 1.0F, 0.0F}, {});
    assert(uncorrected_servo.valid);
    assert(approximately_equal(uncorrected_servo.yaw, 0.40F));
    assert(approximately_equal(uncorrected_servo.pitch, 0.10F));
    const a3vr::Vec3 aligned_weapon{
        std::sin(0.40F) * std::cos(0.10F),
        std::cos(0.40F) * std::cos(0.10F),
        std::sin(0.10F),
    };
    const auto aligned_servo = a3vr::absolute_aim_correction(
        {0.40F, 0.10F}, aligned_weapon, {});
    assert(aligned_servo.valid);
    assert(approximately_equal(aligned_servo.yaw, 0.0F));
    assert(approximately_equal(aligned_servo.pitch, 0.0F));

    a3vr::TrackedPose head{};
    head.orientation_valid = true;
    head.orientation = identity;
    controller.orientation = identity;
    const auto cursor_center = a3vr::controller_cursor_position(
        controller, head, 1.2F, 0.9F);
    assert(cursor_center.valid && approximately_equal(cursor_center.x, 0.5F) &&
           approximately_equal(cursor_center.y, 0.5F));
    controller.orientation = {0.0F, std::sin(half_angle), 0.0F, std::cos(half_angle)};
    const auto cursor_left = a3vr::controller_cursor_position(
        controller, head, 1.2F, 0.9F);
    assert(cursor_left.valid && cursor_left.x < 0.5F);
    controller.orientation = {std::sin(half_angle), 0.0F, 0.0F, std::cos(half_angle)};
    const auto cursor_up = a3vr::controller_cursor_position(
        controller, head, 1.2F, 0.9F);
    assert(cursor_up.valid && cursor_up.y < 0.5F);
    a3vr::TrackedPose head_reference = head;
    head.orientation = {0.0F, std::sin(half_angle), 0.0F, std::cos(half_angle)};
    const auto head_cursor_left = a3vr::head_cursor_position(
        head, head_reference, 1.2F, 0.9F);
    assert(head_cursor_left.valid && head_cursor_left.x < 0.5F);

    const auto idle_movement = a3vr::movement_keys_from_stick(0.1F, -0.1F);
    assert(!idle_movement.forward && !idle_movement.backward &&
           !idle_movement.left && !idle_movement.right);
    const auto diagonal_movement = a3vr::movement_keys_from_stick(-0.8F, 0.9F);
    assert(diagonal_movement.forward && !diagonal_movement.backward &&
           diagonal_movement.left && !diagonal_movement.right);
    // Head-directed locomotion rotates the native soldier in SQF. The stick
    // itself must remain forward here instead of being converted into strafe.
    const auto head_directed_forward = a3vr::movement_keys_from_stick(
        0.0F, 1.0F, 0.25F);
    assert(head_directed_forward.forward &&
           !head_directed_forward.backward &&
           !head_directed_forward.left && !head_directed_forward.right);
    assert(!a3vr::analog_button_pressed(0.20F, false, 0.22F, 0.12F));
    assert(a3vr::analog_button_pressed(0.22F, false, 0.22F, 0.12F));
    assert(a3vr::analog_button_pressed(0.13F, true, 0.22F, 0.12F));
    assert(!a3vr::analog_button_pressed(0.12F, true, 0.22F, 0.12F));
    assert(!a3vr::roomscale_crouch_state(0.29F, false));
    assert(a3vr::roomscale_crouch_state(0.30F, false));
    assert(a3vr::roomscale_crouch_state(0.19F, true));
    assert(!a3vr::roomscale_crouch_state(0.18F, true));

    a3vr::ControllerInputState accessory_input{};
    accessory_input.radial_menu = true;
    accessory_input.reload = true;
    auto accessory_chords = a3vr::weapon_accessory_chords(
        accessory_input, true, false);
    assert(accessory_chords.light_or_laser);
    assert(!accessory_chords.deploy_weapon);
    assert(!accessory_chords.toggle_proxy);
    assert(!accessory_chords.inventory);
    assert(!accessory_chords.map);
    accessory_input.reload = false;
    accessory_input.fire_mode = true;
    accessory_chords = a3vr::weapon_accessory_chords(
        accessory_input, true, false);
    assert(!accessory_chords.light_or_laser);
    assert(accessory_chords.deploy_weapon);
    assert(!accessory_chords.toggle_proxy);
    assert(!accessory_chords.inventory);
    assert(!accessory_chords.map);
    accessory_input.fire_mode = false;
    accessory_input.grenade = true;
    accessory_chords = a3vr::weapon_accessory_chords(
        accessory_input, true, false);
    assert(!accessory_chords.light_or_laser);
    assert(!accessory_chords.deploy_weapon);
    assert(accessory_chords.toggle_proxy);
    assert(!accessory_chords.inventory);
    assert(!accessory_chords.map);
    accessory_input.grenade = false;
    accessory_input.swap_weapon = true;
    accessory_chords = a3vr::weapon_accessory_chords(
        accessory_input, true, false);
    assert(!accessory_chords.light_or_laser);
    assert(!accessory_chords.deploy_weapon);
    assert(!accessory_chords.toggle_proxy);
    assert(accessory_chords.inventory);
    assert(!accessory_chords.map);
    accessory_input.swap_weapon = false;
    accessory_input.interact = true;
    accessory_chords = a3vr::weapon_accessory_chords(
        accessory_input, true, false);
    assert(!accessory_chords.light_or_laser);
    assert(!accessory_chords.deploy_weapon);
    assert(!accessory_chords.toggle_proxy);
    assert(!accessory_chords.inventory);
    assert(accessory_chords.map);
    accessory_chords = a3vr::weapon_accessory_chords(
        accessory_input, true, true);
    assert(!accessory_chords.deploy_weapon && !accessory_chords.toggle_proxy &&
           !accessory_chords.inventory && !accessory_chords.map);
    accessory_chords = a3vr::weapon_accessory_chords(
        accessory_input, false, false);
    assert(!accessory_chords.light_or_laser &&
           !accessory_chords.deploy_weapon && !accessory_chords.toggle_proxy &&
           !accessory_chords.inventory && !accessory_chords.map);

    (void)a3vr::consume_body_yaw_transfer();
    a3vr::request_body_yaw_transfer(1.25F);
    assert(approximately_equal(
        a3vr::consume_body_yaw_transfer(), 1.25F));

    // AbsoluteWeapon POC: the target is a deterministic transform of the
    // complete controller pose, never an accumulated mouse-like angle.
    a3vr::AbsoluteWeaponPoseSolver weapon_solver;
    a3vr::TrackedPose absolute_head{};
    absolute_head.position_valid = true;
    absolute_head.orientation_valid = true;
    absolute_head.position = {0.0F, 1.70F, 0.0F};
    a3vr::TrackedPose absolute_controller{};
    absolute_controller.position_valid = true;
    absolute_controller.orientation_valid = true;
    absolute_controller.position = {0.25F, 1.30F, -0.40F};
    absolute_controller.orientation = {};

    const auto neutral_target = weapon_solver.solve(
        absolute_controller, absolute_head);
    assert(neutral_target.valid);
    assert(approximately_equal(neutral_target.room_pose.position.x, 0.25F));
    assert(approximately_equal(neutral_target.room_pose.position.y, 1.30F));
    assert(approximately_equal(neutral_target.room_pose.position.z, -0.40F));
    assert(approximately_equal(neutral_target.muzzle_direction.x, 0.0F));
    assert(approximately_equal(neutral_target.muzzle_direction.y, 0.0F));
    assert(approximately_equal(neutral_target.muzzle_direction.z, -1.0F));

    absolute_controller.position = {-0.15F, 0.95F, -0.75F};
    const auto translated_target = weapon_solver.solve(
        absolute_controller, absolute_head);
    assert(approximately_equal(translated_target.room_pose.position.x, -0.15F));
    assert(approximately_equal(translated_target.room_pose.position.y, 0.95F));
    assert(approximately_equal(translated_target.room_pose.position.z, -0.75F));

    const float quarter_turn = 0.78539816339F;
    absolute_controller.orientation = {
        std::sin(quarter_turn), 0.0F, 0.0F, std::cos(quarter_turn)};
    const auto downward_target = weapon_solver.solve(
        absolute_controller, absolute_head);
    assert(approximately_equal(downward_target.muzzle_direction.x, 0.0F));
    assert(approximately_equal(downward_target.muzzle_direction.y, 1.0F));
    assert(approximately_equal(downward_target.muzzle_direction.z, 0.0F));

    absolute_controller.orientation = {};
    const auto returned_target = weapon_solver.solve(
        absolute_controller, absolute_head);
    assert(approximately_equal(returned_target.muzzle_direction.x, 0.0F));
    assert(approximately_equal(returned_target.muzzle_direction.y, 0.0F));
    assert(approximately_equal(returned_target.muzzle_direction.z, -1.0F));

    // Moving the HMD after origin capture must not drag or redefine the gun.
    absolute_head.position = {0.60F, 1.20F, 0.50F};
    const auto independent_target = weapon_solver.solve(
        absolute_controller, absolute_head);
    assert(approximately_equal(independent_target.room_pose.position.x, -0.15F));
    assert(approximately_equal(independent_target.room_pose.position.y, 0.95F));
    assert(approximately_equal(independent_target.room_pose.position.z, -0.75F));

    a3vr::WeaponGripCalibration calibration{};
    calibration.position_offset = {0.03F, -0.04F, -0.08F};
    calibration.rotation_offset = a3vr::quaternion_from_yaw_pitch_roll(
        0.25F, -0.10F, 0.15F);
    weapon_solver.set_calibration(calibration);
    const auto calibrated_target = weapon_solver.solve(
        absolute_controller, absolute_head);
    assert(approximately_equal(calibrated_target.room_pose.position.x, -0.12F));
    assert(approximately_equal(calibrated_target.room_pose.position.y, 0.91F));
    assert(approximately_equal(calibrated_target.room_pose.position.z, -0.83F));
    return 0;
}
