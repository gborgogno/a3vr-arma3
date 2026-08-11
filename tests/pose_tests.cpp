#include "../src/pose.hpp"
#include "../src/freetrack_output.hpp"
#include "../src/controller_aim_output.hpp"
#include "../src/controller_input_output.hpp"

#include <cassert>
#include <cmath>

namespace {
bool approximately_equal(const float a, const float b) { return std::abs(a - b) < 0.0001F; }
}

int main() {
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

    const float half_angle = 0.25F;
    tracked.position = {};
    tracked.orientation = {0.0F, std::sin(half_angle), 0.0F, std::cos(half_angle)};
    const auto limited_rotation = a3vr::to_freetrack_pose(tracked);
    assert(approximately_equal(limited_rotation.yaw, 0.125F));
    assert(approximately_equal(limited_rotation.pitch, 0.0F));

    tracked.orientation = {std::sin(half_angle), 0.0F, 0.0F, std::cos(half_angle)};
    const auto limited_vertical = a3vr::to_freetrack_pose(tracked);
    assert(approximately_equal(limited_vertical.yaw, 0.0F));
    assert(approximately_equal(limited_vertical.pitch, 0.125F));

    a3vr::TrackedPose head{};
    head.orientation_valid = true;
    head.orientation = identity;
    a3vr::TrackedPose controller{};
    controller.orientation_valid = true;
    controller.orientation = {0.0F, std::sin(half_angle), 0.0F, std::cos(half_angle)};
    const auto controller_yaw = a3vr::controller_angles_relative_to_head(head, controller);
    assert(approximately_equal(controller_yaw.yaw, -0.5F));
    assert(approximately_equal(controller_yaw.pitch, 0.0F));

    controller.orientation = {std::sin(half_angle), 0.0F, 0.0F, std::cos(half_angle)};
    const auto controller_pitch = a3vr::controller_angles_relative_to_head(head, controller);
    assert(approximately_equal(controller_pitch.yaw, 0.0F));
    assert(approximately_equal(controller_pitch.pitch, 0.5F));

    const auto idle_movement = a3vr::movement_keys_from_stick(0.1F, -0.1F);
    assert(!idle_movement.forward && !idle_movement.backward &&
           !idle_movement.left && !idle_movement.right);
    const auto diagonal_movement = a3vr::movement_keys_from_stick(-0.8F, 0.9F);
    assert(diagonal_movement.forward && !diagonal_movement.backward &&
           diagonal_movement.left && !diagonal_movement.right);
    return 0;
}
