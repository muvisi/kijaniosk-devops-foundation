# KijaniKiosk Cloud Service Model

## Selected Model: Platform as a Service (PaaS)

KijaniKiosk will primarily use a Platform as a Service approach for application deployment.

PaaS provides a good balance between infrastructure control and operational simplicity.

With a pure IaaS model, the engineering team would be responsible for managing virtual machines, operating system updates, patching and other infrastructure activities.

A SaaS model would provide less control because the complete application would be provided by another vendor.

PaaS allows the KijaniKiosk development team to focus primarily on building and deploying the application while the cloud provider manages much of the underlying infrastructure.

## Why PaaS?

The main benefits for KijaniKiosk are:

- Faster application deployment
- Reduced server administration
- Easier application scaling
- Integration with monitoring services
- Reduced infrastructure maintenance
- More time for the team to focus on product development

Some supporting services may still use IaaS components such as virtual networks and subnets.

The overall application deployment strategy, however, will favor managed cloud services where practical.

## Future Considerations

As KijaniKiosk grows, the architecture can evolve to include container platforms, managed databases, automated CI/CD pipelines and Infrastructure as Code.
