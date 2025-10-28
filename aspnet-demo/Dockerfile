# escape=`
FROM mcr.microsoft.com/dotnet/aspnet:6.0-windowsservercore-ltsc2022 AS base
WORKDIR /app
EXPOSE 80

FROM mcr.microsoft.com/dotnet/sdk:6.0-windowsservercore-ltsc2022 AS build
WORKDIR /src
COPY ["aspnet-demo.csproj", "./"]
RUN dotnet restore "aspnet-demo.csproj"
COPY . .
RUN dotnet build "aspnet-demo.csproj" -c Release -o /app/build
RUN dotnet publish "aspnet-demo.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "aspnet-demo.dll"]
