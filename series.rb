# rubocop:disable Naming/MethodName
# rubocop:disable Metrics/MethodLength

CONCENTRATION_A_INITIAL = 1 # mol / L
CONCENTRATION_B_INITIAL = 0 # mol / L
CONCENTRATION_C_INITIAL = 0 # mol / L

PRE_EXPONENTIAL_FACTOR_1 = 3.6 * 10**16 # unitless
PRE_EXPONENTIAL_FACTOR_2 = 1.8 * 10**17 # unitless

ACTIVATION_ENERGY_1 = 145 # kJ / mol
ACTIVATION_ENERGY_2 = 155 # kJ / mol

GAS_CONSTANT = 0.008314 # kJ / (mol * K)

def kA(temperature)
  PRE_EXPONENTIAL_FACTOR_1 * Math.exp(-ACTIVATION_ENERGY_1 / (GAS_CONSTANT * temperature))
end

def kB(temperature)
  PRE_EXPONENTIAL_FACTOR_2 * Math.exp(-ACTIVATION_ENERGY_2 / (GAS_CONSTANT * temperature))
end

def dCA_dt(temperature, concentration_a)
  -kA(temperature) * concentration_a
end

def dCB_dt(temperature, concentration_a, concentration_b)
  kA(temperature) * concentration_a - kB(temperature) * concentration_b
end

def dCC_dt(temperature, concentration_b)
  kB(temperature) * concentration_b
end

def simulate(temperature)
  # Initialize concentrations
  concentration_a = CONCENTRATION_A_INITIAL
  concentration_b = CONCENTRATION_B_INITIAL
  concentration_c = CONCENTRATION_C_INITIAL

  # Initialize time
  time = 0

  concentrations = [[time, concentration_a, concentration_b, concentration_c]]

  # Time step
  time_step = 0.1

  # Simulation loop
  while time < 100
    concentration_a += dCA_dt(temperature, concentration_a) * time_step
    concentration_b += dCB_dt(temperature, concentration_a, concentration_b) * time_step
    concentration_c += dCC_dt(temperature, concentration_b) * time_step

    time += time_step

    concentrations << [time, concentration_a, concentration_b, concentration_c]
  end

  concentrations
end

puts simulate(398)
