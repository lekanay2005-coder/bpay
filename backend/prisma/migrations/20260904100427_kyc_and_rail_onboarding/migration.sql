-- CreateTable
CREATE TABLE "KycProfile" (
    "id" TEXT NOT NULL,
    "appUserId" TEXT NOT NULL,
    "personalInfo" JSONB,
    "address" JSONB,
    "employment" JSONB,
    "sourceOfFunds" TEXT,
    "accountPurpose" TEXT,
    "estimatedMonthlyVolume" INTEGER,
    "identificationSubmittedAt" TIMESTAMP(3),
    "proofOfAddressSubmittedAt" TIMESTAMP(3),
    "biometricSubmittedAt" TIMESTAMP(3),
    "readyAt" TIMESTAMP(3),
    "activatedCurrencies" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "KycProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RailOnboarding" (
    "id" TEXT NOT NULL,
    "appUserId" TEXT NOT NULL,
    "currency" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "workflowId" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RailOnboarding_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "KycProfile_appUserId_key" ON "KycProfile"("appUserId");

-- CreateIndex
CREATE UNIQUE INDEX "RailOnboarding_appUserId_currency_key" ON "RailOnboarding"("appUserId", "currency");

-- AddForeignKey
ALTER TABLE "KycProfile" ADD CONSTRAINT "KycProfile_appUserId_fkey" FOREIGN KEY ("appUserId") REFERENCES "AppUser"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RailOnboarding" ADD CONSTRAINT "RailOnboarding_appUserId_fkey" FOREIGN KEY ("appUserId") REFERENCES "AppUser"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
