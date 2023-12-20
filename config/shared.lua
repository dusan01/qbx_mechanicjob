return {
    maxStatusValues = {
        engine = 1000.0,
        body = 1000.0,
        radiator = 100,
        axle = 100,
        brakes = 100,
        clutch = 100,
        fuel = 100,
    },
    repairCost = {
        body = 'plastic',
        radiator = 'plastic',
        axle = 'steel',
        brakes = 'iron',
        clutch = 'aluminum',
        fuel = 'plastic',
    },
    repairCostAmount = {
        engine = {
            item = 'metalscrap',
            costs = 2,
        },
        body = {
            item = 'plastic',
            costs = 3,
        },
        radiator = {
            item = 'steel',
            costs = 5,
        },
        axle = {
            item = 'aluminum',
            costs = 7,
        },
        brakes = {
            item = 'copper',
            costs = 5,
        },
        clutch = {
            item = 'copper',
            costs = 6,
        },
        fuel = {
            item = 'plastic',
            costs = 5,
        },
    },
    plates = {
        {
            coords = vec3(-327.05, -144.6, 39.0),
            boxData = {
                size = vec3(7.0, 5.15, 5.3),
                rotation = 340.0,
                debugPoly = false
            },
            AttachedVehicle = nil,
        },
        {
            coords = vec3(-340.85, -128.2, 39.0),
            boxData = {
                size = vec3(3.25, 5.7, 4.7),
                rotation = 340.0,
                debugPoly = false
            },
            AttachedVehicle = nil,
        },
    },
    locations = {
        main = vec3(-339.04, -135.53, 39.00),
        duty = vec3(-323.5, -129.2, 39.0),
        stash = vec3(-319.05, -131.95, 39.0),
        garage = vec4(-370.2, -107.8, 39.0, 70.0),
    }
}